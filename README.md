# 마지초등학교 6학년 방학숙제 통합 앱

6학년 동학년 전체(다중 학급)가 함께 사용하는 교육 및 학급 운영 통합 앱입니다.

- **프론트엔드:** Flutter (`flutter_app/`)
- **백엔드:** Firebase (Firestore, Auth, Cloud Functions — `functions/`)
- **보안:** Firestore Security Rules (`firestore.rules`)

## 핵심 설계 원칙

1. **다중 학급(Multi-Class) 아키텍처** — 선생님마다 학급을 개설하고, 학생은 '학급 참여 코드'로 자기 반에 소속됩니다.
2. **공유 데이터와 독립 데이터의 분리**
   - 공유(동학년): 수학 문제 은행(28일), 글쓰기 주제(30일) → 최상위 공유 컬렉션
   - 독립(학급별): 제출/점검/감정/알림 데이터 → `classes/{classId}` 하위에 격리
3. **서버 검증 채점** — 채점 결과(`isCompleted`)는 클라이언트가 직접 쓸 수 없고, Cloud Functions(callable)만 기록합니다. 클라이언트의 실시간 비교는 UX용 즉시 피드백이며, 최종 확정은 서버가 합니다.
4. **실시간 교사 대시보드** — 학생 목록과 학생별 4대 미션 문서를 모두 Firestore 스트림으로 구독하여, 학생이 과제를 제출하는 순간 대시보드에 즉시 반영됩니다.
5. **이중 알림 체계** — ① 매일 저녁 스케줄러가 미제출 학생에게 자동 알림, ② 교사가 대시보드에서 개별/일괄 알림을 즉시 발송(미완료 과목 목록이 자동으로 메시지에 포함).

---

## 1. Firestore DB 스키마 설계안

```
firestore-root
│
├── users/{uid}                          # 전역 역할 조회용 (Security Rules의 기준점)
│     role: "teacher" | "student"
│     name: string
│     classId: string                    # 소속 학급 (교사는 담당 학급)
│     approved: bool                     # 학생: 교사 승인 여부
│
├── joinCodes/{code}                     # 학급 참여 코드 → 학급 매핑
│     classId: string
│     grade: 6
│     isActive: bool
│
├── mathBank/{dayId}                     # ★ 동학년 공유: 수학 28일 × 10문제
│     day: 1..28                         #   단원별 3일(3세트) × 6단원 + 복습 10일
│     unit: string                       #   단원명 (분수의 나눗셈, 전개도, ...)
│     type: "concept" | "review"        #   개념 18일 + 혼합 복습 10일
│     problems: [                        #   하루 10문제
│       { id, kind: "multipleChoice"|"shortAnswer"|"netDrawing",
│         tag: string,                           # ★ 개념 태그 (취약 개념 분석용)
│         question, choices?, answer?,          # 일반 문제
│         answerLines?: [                        # 전개도 문제 (netDrawing)
│           { x1, y1, x2, y2, type: 0|1 }        #   type 0=실선(자르기), 1=점선(접기)
│         ] }
│     ]
│     updatedBy: uid                     # 마지막 수정 교사
│
├── writingTopics/{dayId}                # ★ 동학년 공유: 30일 글쓰기 주제
│     day: 1..30
│     topic: string
│     guide: string                      # 글쓰기 안내문
│
└── classes/{classId}                    # ★ 학급별 독립 데이터의 루트
      name: "6학년 1반"
      grade: 6
      teacherId: uid
      joinCode: string
      isActive: bool                     # 스케줄러 순회 대상 여부
      missionStartDate: "2026-07-20"     # 방학 미션 1일차 기준일
      │
      ├── selfCheckTemplates/{dateKey}   # 교사가 부여한 당일 자기 점검 항목
      │     items: [ { id, label } ]     #   예: 알림장 확인, 준비물, 독서 30분
      │
      └── students/{uid}
            name, approved, joinedAt
            notifications: [             # 스케줄러가 arrayUnion으로 삽입
              { id, type, message, date, read }
            ]
            │
            ├── mathProgress/{dayId}         # 수학 제출 (dayId = day01..day28)
            │     answers: map               # 학생 답안 (클라이언트 기록 가능)
            │     userLines: [...]           # 전개도 그리기 결과
            │     isCompleted: bool          # ★ 서버(Cloud Function)만 쓰기 가능
            │     correctCount, total        # ★ 서버 채점 점수 (예: 8/10)
            │     wrongTags: [string]        # ★ 틀린 문제의 개념 태그 → 개념 분석
            │     attempts: number           # ★ 제출 횟수
            │     gradedAt: timestamp        # ★ 서버만 쓰기 가능

            ├── exercises/{dateKey}          # 오늘의 운동 기록 (여러 종목 가능)
            │     entries: [                 #   기록 1개 이상이면 미션 완료
            │       { categoryId, categoryName, emoji,
            │         detail?      # 맨몸 운동·기타: 주관식 (예: 팔굽혀펴기 20개)
            │         value?, unit?  # 달리기·자전거·줄넘기: 수치 (km, 개)
            │         sport?, minutes?  # 스포츠: 종목 + 시간(분)
            │       } ]
            │
            ├── writingSubmissions/{dayId}   # 글쓰기 제출 (day01..day30)
            │     content: string
            │     submittedAt: timestamp     # ★ 서버 타임스탬프 강제
            │     isSubmitted: bool          # ★ 서버만 확정
            │
            ├── selfChecks/{dateKey}         # 일일 자기 점검 (dateKey = 2026-07-20)
            │     checkedItemIds: [string]
            │     allDone: bool
            │
            └── emotions/{dateKey}           # 일일 감정 체크인 (하루 여러 번 갱신 가능)
                  emoji: string              # 🤩 😄 🙂 😐 😴 😢 😡 😟
                  mood: string               # positive | neutral | negative
                  reason: string             # 기분의 이유 (선택지에서 고름)
                  comment: string
                  checkInCount: number       # 오늘 체크인 횟수
                  negativeCount: number      # 오늘 부정적 기분 기록 횟수
                  createdAt: timestamp

      ├── teacherAlerts/{studentId_dateKey}  # ★ 감정 위기 경고 (Cloud Function만 생성)
      │     type: "emotionAlert"             #   부정 감정 하루 3회 이상 또는
      │     studentId, studentName           #   최근 3일 중 2일 이상이면 자동 생성
      │     message, emoji, reason, comment  #   담임만 열람 가능 (학생 열람 불가)
      │     date, read: bool
```

### 설계 근거

| 요구사항 | 반영 방식 |
|---|---|
| 다중 학급 | 모든 학급 데이터가 `classes/{classId}` 아래에 격리. 스케줄러는 `isActive == true` 학급만 순회 |
| 공유 문제 은행 | `mathBank`, `writingTopics`를 최상위에 두어 모든 교사가 공동 편집, 모든 학급이 읽기 |
| 참여 코드 가입 | `joinCodes/{code}` 조회 → callable 함수가 검증 후 학급에 학생 등록 |
| 채점 조작 방지 | `isCompleted`/`gradedAt`은 Rules에서 클라이언트 쓰기 차단, Admin SDK(Functions)만 기록 |
| 교사 대시보드 | 학급 하위 컬렉션을 collectionGroup 없이 단순 쿼리로 당일 현황 집계 가능 |

---

## 2. 폴더 구성

```
summervacation/
├── README.md                ← 본 문서 (스키마 설계안)
├── firebase.json
├── firestore.rules          ← 보안 규칙
├── functions/               ← Node.js Cloud Functions
│   ├── package.json
│   └── index.js             ← 스케줄러 + 채점/가입 callable
└── flutter_app/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── models/models.dart
        ├── services/firestore_service.dart
        ├── data/math_curriculum.dart    ← 28일 커리큘럼 시드
        ├── data/writing_topics.dart     ← 30일 주제 시드
        ├── widgets/
        │   ├── net_drawing_board.dart   ← 전개도 그리기 + 실시간 자동 채점
        │   ├── self_check_list.dart     ← 일일 자기 점검 체크리스트
        │   └── streak_tracker.dart      ← 글쓰기 연속 제출 트래커
        └── screens/
            ├── auth/join_class_screen.dart
            ├── student/student_home_screen.dart
            ├── student/math_mission_screen.dart
            ├── student/writing_screen.dart
            ├── student/emotion_checkin_screen.dart
            └── teacher/teacher_dashboard_screen.dart
```

## 3. 배포 방법

```bash
# Functions 배포
cd functions && npm install
firebase deploy --only functions

# 보안 규칙 배포
firebase deploy --only firestore:rules

# Flutter 실행 (FlutterFire CLI로 firebase_options.dart 생성 후)
cd flutter_app
flutterfire configure
flutter run
```
