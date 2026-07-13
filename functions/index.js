/**
 * 6학년 여름방학 숙제 앱 — Cloud Functions
 *
 *  1) dailyMissionCheck  : 매일 저녁, 모든 활성 학급을 순회하며 4대 미션
 *                          미제출 학생에게 맞춤 알림을 자동 삽입하는 스케줄러
 *  2) joinClass          : 학급 참여 코드로 학생을 자기 반에 등록하는 callable
 *  3) gradeMathDay       : 수학 답안(전개도 포함)을 서버에서 검증하고
 *                          isCompleted를 확정하는 callable (조작 방지)
 *  4) submitWriting      : 글쓰기 제출을 서버 타임스탬프로 확정하는 callable
 *  5) onEmotionCheckIn   : 부정적 감정이 반복 기록되면(하루 3회 이상 또는
 *                          최근 3일 중 2일 이상) 담당 교사에게 경고 알림 생성
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "asia-northeast3" }); // 서울 리전

/** KST 기준 오늘 날짜 키 (예: "2026-07-20") */
function todayKeyKST() {
  return new Date(Date.now() + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

/** 방학 시작일 기준 오늘이 미션 며칠차인지 계산 → "day07" 형태 반환 */
function missionDayId(missionStartDate, maxDay) {
  const start = new Date(`${missionStartDate}T00:00:00+09:00`);
  const now = new Date();
  const diff = Math.floor((now - start) / (24 * 60 * 60 * 1000)) + 1;
  if (diff < 1 || diff > maxDay) return null; // 미션 기간 밖
  return `day${String(diff).padStart(2, "0")}`;
}

// =====================================================================
// 1) 동적 타겟팅 스케줄러 — 매일 20:00 KST, 모든 활성 학급 순회
// =====================================================================
exports.dailyMissionCheck = onSchedule(
  { schedule: "0 20 * * *", timeZone: "Asia/Seoul" },
  async () => {
    const dateKey = todayKeyKST();

    // DB에 등록된 "모든 활성 6학년 학급"을 동적으로 조회 (하드코딩 없음)
    const classesSnap = await db
      .collection("classes")
      .where("isActive", "==", true)
      .where("grade", "==", 6)
      .get();

    console.log(`[dailyMissionCheck] ${dateKey} — 활성 학급 ${classesSnap.size}개 순회 시작`);

    for (const classDoc of classesSnap.docs) {
      const cls = classDoc.data();
      const mathDayId = missionDayId(cls.missionStartDate, 28);
      const writingDayId = missionDayId(cls.missionStartDate, 30);

      const studentsSnap = await classDoc.ref
        .collection("students")
        .where("approved", "==", true)
        .get();

      const batch = db.batch();
      let notified = 0;

      // 학급 내 학생별 미션 검사는 병렬 처리
      await Promise.all(
        studentsSnap.docs.map(async (studentDoc) => {
          const missing = await findMissingMissions(
            studentDoc.ref, dateKey, mathDayId, writingDayId
          );
          if (missing.length === 0) return;

          const notifications = missing.map((m) => ({
            id: crypto.randomUUID(),
            type: m.type,
            message: m.message,
            date: dateKey,
            read: false,
          }));
          batch.update(studentDoc.ref, {
            notifications: admin.firestore.FieldValue.arrayUnion(...notifications),
          });
          notified += 1;
        })
      );

      await batch.commit();
      console.log(
        `[dailyMissionCheck] ${cls.name}: 학생 ${studentsSnap.size}명 중 ${notified}명에게 알림 발송`
      );
    }
  }
);

/** 한 학생의 당일 4대 미션 수행 여부를 확인하고 미완료 목록을 반환 */
async function findMissingMissions(studentRef, dateKey, mathDayId, writingDayId) {
  const [mathSnap, writingSnap, selfCheckSnap, emotionSnap, exerciseSnap] = await Promise.all([
    mathDayId ? studentRef.collection("mathProgress").doc(mathDayId).get() : null,
    writingDayId ? studentRef.collection("writingSubmissions").doc(writingDayId).get() : null,
    studentRef.collection("selfChecks").doc(dateKey).get(),
    studentRef.collection("emotions").doc(dateKey).get(),
    studentRef.collection("exercises").doc(dateKey).get(),
  ]);

  const missing = [];
  if (mathDayId && !(mathSnap.exists && mathSnap.data().isCompleted === true)) {
    missing.push({
      type: "math",
      message: "오늘의 수학 미션이 아직 완료되지 않았어요! 📐",
    });
  }
  if (writingDayId && !(writingSnap.exists && writingSnap.data().isSubmitted === true)) {
    missing.push({
      type: "writing",
      message: "오늘의 글쓰기 주제가 기다리고 있어요! ✍️",
    });
  }
  if (!(selfCheckSnap.exists && selfCheckSnap.data().allDone === true)) {
    missing.push({
      type: "selfCheck",
      message: "오늘의 자기 점검 체크리스트를 완료해 주세요! ✅",
    });
  }
  if (!emotionSnap.exists) {
    missing.push({
      type: "emotion",
      message: "오늘 기분은 어땠나요? 감정 체크인을 잊지 마세요! 😊",
    });
  }
  if (!(exerciseSnap.exists && (exerciseSnap.data().entries ?? []).length > 0)) {
    missing.push({
      type: "exercise",
      message: "오늘 몸을 움직였나요? 운동 기록을 남겨 주세요! 🏃",
    });
  }
  return missing;
}

// =====================================================================
// 2-a) 학급 개설 callable — 교사가 지역을 골라 학급을 만들면
//      참여 코드(6자리)와 비밀번호(4자리 숫자)를 발급한다.
// =====================================================================
const REGIONS = [
  "서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종",
  "경기", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주",
];

exports.createClass = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

  const { region, school, className, teacherName, missionStartDate } =
    request.data ?? {};
  if (!REGIONS.includes(region)) {
    throw new HttpsError("invalid-argument", "지역을 선택해 주세요.");
  }
  for (const [field, v] of [["학교 이름", school], ["학급 이름", className], ["선생님 이름", teacherName]]) {
    if (typeof v !== "string" || !v.trim()) {
      throw new HttpsError("invalid-argument", `${field}을(를) 입력해 주세요.`);
    }
  }
  if (typeof missionStartDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(missionStartDate)) {
    throw new HttpsError("invalid-argument", "방학 시작일 형식이 올바르지 않습니다. (예: 2026-07-20)");
  }

  const userSnap = await db.collection("users").doc(uid).get();
  if (userSnap.exists && userSnap.data().classId) {
    throw new HttpsError("already-exists", "이미 개설했거나 소속된 학급이 있습니다.");
  }

  // 겹치지 않는 참여 코드 생성 (헷갈리는 문자 제외한 6자리)
  const CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  let joinCode;
  for (let i = 0; i < 10; i++) {
    joinCode = Array.from({ length: 6 },
      () => CHARS[crypto.randomInt(CHARS.length)]).join("");
    if (!(await db.collection("joinCodes").doc(joinCode).get()).exists) break;
    joinCode = null;
  }
  if (!joinCode) throw new HttpsError("internal", "코드 생성에 실패했습니다. 다시 시도해 주세요.");
  const password = String(crypto.randomInt(10000)).padStart(4, "0");

  const classRef = db.collection("classes").doc();
  const batch = db.batch();
  batch.set(db.collection("users").doc(uid), {
    role: "teacher",
    name: teacherName.trim(),
    classId: classRef.id,
    approved: true,
  }, { merge: true });
  batch.set(classRef, {
    name: `${school.trim()} ${className.trim()}`,
    school: school.trim(),
    region,
    grade: 6,
    teacherId: uid,
    joinCode,
    isActive: true,
    missionStartDate,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(db.collection("joinCodes").doc(joinCode), {
    classId: classRef.id,
    password, // joinCodes는 Rules에서 클라이언트 접근 전면 차단 — 서버만 검증
    grade: 6,
    isActive: true,
  });
  // 담임이 대시보드에서 코드/비밀번호를 다시 확인할 수 있도록
  // 교사 전용(private) 문서에도 보관 (학생은 Rules로 읽기 차단)
  batch.set(classRef.collection("private").doc("credentials"), {
    joinCode,
    password,
  });
  await batch.commit();

  return { classId: classRef.id, joinCode, password };
});

// =====================================================================
// 2-b) 학급 가입 callable — 참여 코드 + 비밀번호 검증 후 학생 등록
// =====================================================================
exports.joinClass = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

  const { code, password, name } = request.data ?? {};
  if (typeof code !== "string" || !code.trim() || typeof name !== "string" || !name.trim()) {
    throw new HttpsError("invalid-argument", "참여 코드와 이름을 입력해 주세요.");
  }

  const codeSnap = await db.collection("joinCodes").doc(code.trim().toUpperCase()).get();
  if (!codeSnap.exists || codeSnap.data().isActive !== true) {
    throw new HttpsError("not-found", "유효하지 않은 학급 참여 코드입니다.");
  }
  if (String(password ?? "") !== String(codeSnap.data().password ?? "")) {
    throw new HttpsError("permission-denied", "비밀번호가 맞지 않아요. 선생님께 다시 확인해 보세요.");
  }
  const { classId } = codeSnap.data();

  const userRef = db.collection("users").doc(uid);
  const existing = await userRef.get();
  if (existing.exists && existing.data().classId) {
    throw new HttpsError("already-exists", "이미 학급에 소속되어 있습니다.");
  }

  // 역할/학급 배정은 서버만 수행 (Rules에서 클라이언트 차단됨)
  const batch = db.batch();
  batch.set(userRef, {
    role: "student",
    name: name.trim(),
    classId,
    approved: true, // 정책상 교사 수동 승인을 원하면 false로 변경
  }, { merge: true });
  batch.set(db.doc(`classes/${classId}/students/${uid}`), {
    name: name.trim(),
    approved: true,
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    notifications: [],
  });
  await batch.commit();

  return { ok: true, classId };
});

// =====================================================================
// 3) 수학 채점 callable — 서버 검증 후에만 isCompleted 확정
// =====================================================================
exports.gradeMathDay = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

  const { dayId, answers, netLines } = request.data ?? {};
  if (typeof dayId !== "string" || !/^day\d{2}$/.test(dayId)) {
    throw new HttpsError("invalid-argument", "dayId가 올바르지 않습니다.");
  }

  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.data();
  if (!user || user.role !== "student" || !user.classId || user.approved !== true) {
    throw new HttpsError("permission-denied", "승인된 학생만 제출할 수 있습니다.");
  }

  const bankSnap = await db.collection("mathBank").doc(dayId).get();
  if (!bankSnap.exists) throw new HttpsError("not-found", "해당 일차 문제가 없습니다.");
  const problems = bankSnap.data().problems ?? [];

  // ---- 서버 측 채점: 문제별로 채점하고 틀린 문제의 개념 태그를 기록 ----
  //      (교사 대시보드 '개념 분석'이 wrongTags를 집계해 취약 개념을 보여줌)
  const wrongTags = [];
  const wrongProblemIds = [];
  for (const p of problems) {
    let correct;
    if (p.kind === "netDrawing") {
      correct = linesMatch(netLines?.[p.id] ?? [], p.answerLines ?? []);
    } else {
      const given = String(answers?.[p.id] ?? "").trim().replace(/\s+/g, "");
      correct = given === String(p.answer).trim().replace(/\s+/g, "");
    }
    if (!correct) {
      wrongProblemIds.push(p.id);
      if (p.tag) wrongTags.push(p.tag);
    }
  }
  const total = problems.length;
  const correctCount = total - wrongProblemIds.length;
  const allCorrect = wrongProblemIds.length === 0;

  const progressRef = db.doc(
    `classes/${user.classId}/students/${uid}/mathProgress/${dayId}`
  );
  await progressRef.set(
    {
      answers: answers ?? {},
      userLines: netLines ?? {},
      isCompleted: allCorrect, // Admin SDK는 Rules를 우회 — 서버만 확정 가능
      correctCount,
      total,
      wrongTags,          // 마지막 제출 기준 취약 개념 태그
      wrongProblemIds,
      attempts: admin.firestore.FieldValue.increment(1),
      gradedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { isCompleted: allCorrect, correctCount, total, wrongProblemIds };
});

/**
 * 전개도 선 비교 — 방향/순서 무관.
 * 각 선분을 "작은 끝점 우선"으로 정규화한 뒤 집합 동등성 검사.
 * (클라이언트 NetDrawingBoard와 동일한 알고리즘 — 이중 검증)
 */
function linesMatch(userLines, answerLines) {
  const normalize = (l) => {
    const [a, b] =
      l.x1 < l.x2 || (l.x1 === l.x2 && l.y1 <= l.y2)
        ? [[l.x1, l.y1], [l.x2, l.y2]]
        : [[l.x2, l.y2], [l.x1, l.y1]];
    return `${a[0]},${a[1]}-${b[0]},${b[1]}:${l.type}`;
  };
  const userSet = new Set(userLines.map(normalize));
  const answerSet = new Set(answerLines.map(normalize));
  if (userSet.size !== answerSet.size) return false;
  for (const key of answerSet) if (!userSet.has(key)) return false;
  return true;
}

// =====================================================================
// 4) 글쓰기 제출 callable — 서버 타임스탬프로 제출 확정
// =====================================================================
exports.submitWriting = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

  const { dayId, content } = request.data ?? {};
  if (typeof dayId !== "string" || !/^day\d{2}$/.test(dayId)) {
    throw new HttpsError("invalid-argument", "dayId가 올바르지 않습니다.");
  }
  if (typeof content !== "string" || content.trim().length < 100) {
    throw new HttpsError("invalid-argument", "글은 최소 100자 이상 작성해 주세요.");
  }

  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.data();
  if (!user || user.role !== "student" || !user.classId || user.approved !== true) {
    throw new HttpsError("permission-denied", "승인된 학생만 제출할 수 있습니다.");
  }

  await db
    .doc(`classes/${user.classId}/students/${uid}/writingSubmissions/${dayId}`)
    .set(
      {
        content: content.trim(),
        isSubmitted: true,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return { ok: true };
});

// =====================================================================
// 5) 감정 위기 신호 감지 트리거 — 부정적 감정 반복 시 담임에게 경고
//
//    발동 조건 (둘 중 하나):
//      a) 오늘 하루에 부정적 기분을 3회 이상 반복 기록 (negativeCount >= 3)
//      b) 최근 3일의 체크인 중 2일 이상이 부정적 기분
//    경고는 classes/{classId}/teacherAlerts/{studentId_dateKey} 문서로
//    생성되며(하루 1건으로 중복 방지), 교사 대시보드 상단에 표시된다.
// =====================================================================
exports.onEmotionCheckIn = onDocumentWritten(
  "classes/{classId}/students/{studentId}/emotions/{dateKey}",
  async (event) => {
    const after = event.data?.after?.data();
    if (!after || after.mood !== "negative") return;

    const { classId, studentId, dateKey } = event.params;
    const sameDayNegatives = after.negativeCount ?? 1;

    // 최근 3일(문서 ID = 날짜 키이므로 내림차순 정렬)의 부정 감정 일수 집계
    const recentSnap = await db
      .collection(`classes/${classId}/students/${studentId}/emotions`)
      .orderBy(admin.firestore.FieldPath.documentId(), "desc")
      .limit(3)
      .get();
    const negativeDays = recentSnap.docs.filter(
      (d) => d.data().mood === "negative"
    ).length;

    const repeatedToday = sameDayNegatives >= 3;
    const repeatedDays = negativeDays >= 2;
    if (!repeatedToday && !repeatedDays) return;

    const studentSnap = await db
      .doc(`classes/${classId}/students/${studentId}`)
      .get();
    const studentName = studentSnap.data()?.name ?? "학생";

    const trigger = repeatedToday
      ? `오늘 하루에 힘든 기분을 ${sameDayNegatives}번 기록했어요.`
      : `최근 3일 중 ${negativeDays}일 동안 힘든 기분을 기록했어요.`;

    // 하루 1건으로 중복 방지 (같은 ID에 덮어쓰기)
    await db
      .doc(`classes/${classId}/teacherAlerts/${studentId}_${dateKey}`)
      .set({
        type: "emotionAlert",
        studentId,
        studentName,
        message: `💛 ${studentName} 학생의 마음을 살펴봐 주세요. ${trigger}`,
        emoji: after.emoji ?? "",
        reason: after.reason ?? "",
        comment: after.comment ?? "",
        date: dateKey,
        read: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    console.log(
      `[onEmotionCheckIn] ${classId}/${studentName}: 감정 경고 생성 (${trigger})`
    );
  }
);

// =====================================================================
// 6) 지역별 비식별 통계 집계 — 매일 21:30 KST
//
//    이름·UID 등 개인 식별 정보 없이, 지역 단위로만 집계한다:
//      - 운동: 오늘 운동을 기록한 학생 비율
//      - 정서: 오늘 감정 체크인의 긍정/보통/부정 분포
//    결과는 regionStats/{dateKey} 문서에 저장되며,
//    Rules상 role == 'admin' 사용자만 읽을 수 있다.
// =====================================================================
exports.aggregateRegionStats = onSchedule(
  { schedule: "30 21 * * *", timeZone: "Asia/Seoul" },
  async () => {
    const dateKey = todayKeyKST();
    const classesSnap = await db
      .collection("classes")
      .where("isActive", "==", true)
      .get();

    // region → { students, exercised, checkedIn, positive, neutral, negative }
    const regions = {};

    for (const classDoc of classesSnap.docs) {
      const region = classDoc.data().region ?? "미지정";
      const r = (regions[region] ??= {
        students: 0, exercised: 0, checkedIn: 0,
        positive: 0, neutral: 0, negative: 0,
      });

      const studentsSnap = await classDoc.ref
        .collection("students")
        .where("approved", "==", true)
        .get();
      r.students += studentsSnap.size;

      await Promise.all(
        studentsSnap.docs.map(async (studentDoc) => {
          const [exSnap, emoSnap] = await Promise.all([
            studentDoc.ref.collection("exercises").doc(dateKey).get(),
            studentDoc.ref.collection("emotions").doc(dateKey).get(),
          ]);
          if (exSnap.exists && (exSnap.data().entries ?? []).length > 0) {
            r.exercised += 1;
          }
          if (emoSnap.exists) {
            r.checkedIn += 1;
            const mood = emoSnap.data().mood;
            if (mood === "positive") r.positive += 1;
            else if (mood === "negative") r.negative += 1;
            else r.neutral += 1;
          }
        })
      );
    }

    await db.doc(`regionStats/${dateKey}`).set({
      date: dateKey,
      regions,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`[aggregateRegionStats] ${dateKey}: ${Object.keys(regions).length}개 지역 집계 완료`);
  }
);
