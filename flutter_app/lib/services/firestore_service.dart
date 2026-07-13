import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import '../widgets/net_drawing_board.dart';

/// Firestore / Cloud Functions 접근을 한곳에 모은 서비스 레이어
class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;
  final _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  String dateKey([DateTime? d]) {
    final t = d ?? DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  String dayId(int day) => 'day${day.toString().padLeft(2, '0')}';

  // ---------- 사용자 / 학급 ----------
  Stream<AppUser> watchMe() =>
      _db.doc('users/$uid').snapshots().map(AppUser.fromDoc);

  Future<SchoolClass> getClass(String classId) async =>
      SchoolClass.fromDoc(await _db.doc('classes/$classId').get());

  /// 학급 개설 (교사) — 서버가 참여 코드/비밀번호를 발급해 반환
  Future<Map<String, dynamic>> createClass({
    required String region,
    required String school,
    required String className,
    required String teacherName,
    required String missionStartDate,
  }) async {
    final result = await _functions.httpsCallable('createClass').call({
      'region': region,
      'school': school,
      'className': className,
      'teacherName': teacherName,
      'missionStartDate': missionStartDate,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// 학급 참여 코드 + 비밀번호로 가입 (서버 검증 — joinClass callable)
  Future<void> joinClassWithCode(
      String code, String password, String name) async {
    await _functions
        .httpsCallable('joinClass')
        .call({'code': code, 'password': password, 'name': name});
  }

  /// 학급 내 학생 문서 스트림 (알림 목록 등)
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchStudentDoc(
          String classId) =>
      _db.doc('classes/$classId/students/$uid').snapshots();

  // ---------- 공유 콘텐츠 ----------
  Future<MathDay?> getMathDay(int day) async {
    final doc = await _db.doc('mathBank/${dayId(day)}').get();
    return doc.exists ? MathDay.fromDoc(doc) : null;
  }

  Future<WritingTopic?> getWritingTopic(int day) async {
    final doc = await _db.doc('writingTopics/${dayId(day)}').get();
    return doc.exists ? WritingTopic.fromDoc(doc) : null;
  }

  // ---------- 학생 미션 제출 ----------
  /// 수학 답안 제출 → 서버가 채점하고 isCompleted 확정
  Future<bool> submitMathDay({
    required int day,
    required Map<String, String> answers,
    required Map<String, List<NetLine>> netLines,
  }) async {
    final result = await _functions.httpsCallable('gradeMathDay').call({
      'dayId': dayId(day),
      'answers': answers,
      'netLines': netLines.map(
          (k, v) => MapEntry(k, v.map((l) => l.toJson()).toList())),
    });
    return result.data['isCompleted'] == true;
  }

  /// 글쓰기 제출 → 서버 타임스탬프로 확정
  Future<void> submitWriting(int day, String content) async {
    await _functions
        .httpsCallable('submitWriting')
        .call({'dayId': dayId(day), 'content': content});
  }

  /// 감정 체크인 — 기분(emoji/mood)과 이유(reason)를 함께 기록.
  /// 하루에 여러 번 다시 체크인할 수 있으며, 부정적 기분(negative)을
  /// 반복해서 기록하면 negativeCount가 쌓여 Cloud Function이
  /// 담당 교사에게 자동으로 경고 알림을 만든다.
  Future<void> checkInEmotion(
    String classId, {
    required String emoji,
    required String mood, // 'positive' | 'neutral' | 'negative'
    required String reason,
    String comment = '',
  }) async {
    final ref =
        _db.doc('classes/$classId/students/$uid/emotions/${dateKey()}');
    final exists = (await ref.get()).exists;
    await ref.set({
      'emoji': emoji,
      'mood': mood,
      'reason': reason,
      'comment': comment,
      // createdAt은 최초 1회만 기록 (보안 규칙이 수정 시 변경을 차단)
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'checkInCount': FieldValue.increment(1),
      if (mood == 'negative') 'negativeCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<bool> hasCheckedInToday(String classId) async {
    final doc = await _db
        .doc('classes/$classId/students/$uid/emotions/${dateKey()}')
        .get();
    return doc.exists;
  }

  // ---------- 운동 기록 ----------
  DocumentReference<Map<String, dynamic>> _exerciseRef(String classId) =>
      _db.doc('classes/$classId/students/$uid/exercises/${dateKey()}');

  /// 오늘의 운동 기록 실시간 스트림
  Stream<List<Map<String, dynamic>>> watchTodayExercises(String classId) =>
      _exerciseRef(classId).snapshots().map((d) =>
          List<Map<String, dynamic>>.from(d.data()?['entries'] ?? []));

  /// 운동 기록 추가 (하루에 여러 종목 기록 가능)
  Future<void> addExerciseEntry(
      String classId, Map<String, dynamic> entry) async {
    await _exerciseRef(classId).set({
      'entries': FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 운동 기록 삭제 (본인 기록만)
  Future<void> removeExerciseEntry(
      String classId, Map<String, dynamic> entry) async {
    await _exerciseRef(classId).update({
      'entries': FieldValue.arrayRemove([entry]),
    });
  }

  /// 제출 완료한 글쓰기 day 번호 집합 (Streak 트래커용)
  Stream<Set<int>> watchSubmittedWritingDays(String classId) => _db
      .collection('classes/$classId/students/$uid/writingSubmissions')
      .where('isSubmitted', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => int.tryParse(d.id.replaceFirst('day', '')) ?? 0)
          .where((n) => n > 0)
          .toSet());

  // ---------- 교사 대시보드 ----------
  /// 학급 학생 목록 실시간 스트림 (가입/탈퇴 즉시 반영)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchClassStudents(
          String classId) =>
      _db
          .collection('classes/$classId/students')
          .orderBy('name')
          .snapshots();

  /// 한 학생의 당일 4대 미션 현황 실시간 스트림
  /// (수학·글쓰기·자기점검·감정 4개 문서를 combineLatest로 합성)
  Stream<Map<String, dynamic>> watchStudentDailyStatus(
      String classId, String studentUid, int missionDay) {
    final base = 'classes/$classId/students/$studentUid';
    final today = dateKey();
    final streams = [
      _db.doc('$base/mathProgress/${dayId(missionDay)}').snapshots(),
      _db.doc('$base/writingSubmissions/${dayId(missionDay)}').snapshots(),
      _db.doc('$base/selfChecks/$today').snapshots(),
      _db.doc('$base/emotions/$today').snapshots(),
      _db.doc('$base/exercises/$today').snapshots(),
    ];
    return _combineLatest(streams).map((docs) => {
          'math': docs[0].data()?['isCompleted'] == true,
          'mathScore': docs[0].data()?['correctCount'],
          'mathTotal': docs[0].data()?['total'],
          'writing': docs[1].data()?['isSubmitted'] == true,
          'selfCheck': docs[2].data()?['allDone'] == true,
          'emotionEmoji': docs[3].data()?['emoji'],
          'emotionMood': docs[3].data()?['mood'],
          'emotionReason': docs[3].data()?['reason'],
          'emotionComment': docs[3].data()?['comment'],
          'exercise':
              (docs[4].data()?['entries'] as List? ?? []).isNotEmpty,
        });
  }

  /// 여러 문서 스트림의 최신 스냅샷을 하나의 리스트 스트림으로 합성
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> _combineLatest(
      List<Stream<DocumentSnapshot<Map<String, dynamic>>>> streams) {
    late StreamController<List<DocumentSnapshot<Map<String, dynamic>>>>
        controller;
    final latest = List<DocumentSnapshot<Map<String, dynamic>>?>.filled(
        streams.length, null);
    final subs = <StreamSubscription>[];

    controller = StreamController(
      onListen: () {
        for (var i = 0; i < streams.length; i++) {
          subs.add(streams[i].listen((snap) {
            latest[i] = snap;
            if (!latest.contains(null)) {
              controller.add(latest
                  .cast<DocumentSnapshot<Map<String, dynamic>>>()
                  .toList());
            }
          }, onError: controller.addError));
        }
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// 담임에게 온 감정 경고 알림(미확인) 실시간 스트림
  /// (Cloud Function이 부정적 감정 반복 감지 시 생성)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTeacherAlerts(
          String classId) =>
      _db
          .collection('classes/$classId/teacherAlerts')
          .where('read', isEqualTo: false)
          .snapshots();

  /// 감정 경고 알림 확인 처리
  Future<void> markAlertRead(String classId, String alertId) => _db
      .doc('classes/$classId/teacherAlerts/$alertId')
      .update({'read': true});

  /// 교사 → 학생 즉시 알림 발송 (학생 문서 notifications 배열에 삽입)
  Future<void> sendReminderToStudent(
      String classId, String studentUid, String message) async {
    await _db.doc('classes/$classId/students/$studentUid').update({
      'notifications': FieldValue.arrayUnion([
        {
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'type': 'reminder',
          'message': message,
          'date': dateKey(),
          'read': false,
        }
      ]),
    });
  }

  /// 미완료 미션이 있는 모든 학생에게 일괄 알림 발송.
  /// 발송한 학생 수를 반환한다.
  Future<int> sendRemindersToIncomplete(String classId, int missionDay) async {
    final rows = await fetchDailyStatus(classId, missionDay);
    var sent = 0;
    for (final r in rows) {
      final missing = <String>[
        if (r['math'] != true) '수학',
        if (r['writing'] != true) '글쓰기',
        if (r['selfCheck'] != true) '자기 점검',
        if (r['emotionEmoji'] == null) '감정 체크인',
        if (r['exercise'] != true) '운동',
      ];
      if (missing.isEmpty) continue;
      await sendReminderToStudent(
        classId,
        r['uid'] as String,
        '선생님의 알림: 오늘의 ${missing.join(', ')} 미션을 잊지 마세요! 📣',
      );
      sent++;
    }
    return sent;
  }

  /// 학급 학생 전체의 당일 미션 현황을 한 번에 조회 (일괄 알림 발송용)
  Future<List<Map<String, dynamic>>> fetchDailyStatus(
      String classId, int missionDay) async {
    final students =
        await _db.collection('classes/$classId/students').get();
    final today = dateKey();

    return Future.wait(students.docs.map((s) async {
      final base = 'classes/$classId/students/${s.id}';
      final results = await Future.wait([
        _db.doc('$base/mathProgress/${dayId(missionDay)}').get(),
        _db.doc('$base/writingSubmissions/${dayId(missionDay)}').get(),
        _db.doc('$base/selfChecks/$today').get(),
        _db.doc('$base/emotions/$today').get(),
        _db.doc('$base/exercises/$today').get(),
      ]);
      return {
        'uid': s.id,
        'name': s.data()['name'],
        'math': results[0].data()?['isCompleted'] == true,
        'writing': results[1].data()?['isSubmitted'] == true,
        'selfCheck': results[2].data()?['allDone'] == true,
        'emotionEmoji': results[3].data()?['emoji'],
        'emotionComment': results[3].data()?['comment'],
        'exercise':
            (results[4].data()?['entries'] as List? ?? []).isNotEmpty,
      };
    }));
  }

  // ---------- 과제 달성도 리포트 (교사용, 방학 종료 후 일괄 출력) ----------
  /// 학급 전체 학생의 방학 과제 달성도를 집계해 반환.
  /// 학생별: 수학 완료 일수/평균 정답률, 글쓰기 제출 일수, 자기 점검 완료 일수,
  ///        운동 기록 일수, 감정 체크인 일수
  Future<List<Map<String, dynamic>>> fetchAchievementReport(
      String classId) async {
    final students = await _db.collection('classes/$classId/students').get();

    final rows = await Future.wait(students.docs.map((s) async {
      final base = 'classes/$classId/students/${s.id}';
      final results = await Future.wait([
        _db.collection('$base/mathProgress').get(),
        _db.collection('$base/writingSubmissions').get(),
        _db.collection('$base/selfChecks').get(),
        _db.collection('$base/exercises').get(),
        _db.collection('$base/emotions').get(),
      ]);

      final math = results[0].docs;
      final mathDone =
          math.where((d) => d.data()['isCompleted'] == true).length;
      var scoreSum = 0.0;
      var scored = 0;
      for (final d in math) {
        final total = (d.data()['total'] as num?)?.toDouble() ?? 0;
        if (total > 0) {
          scoreSum +=
              ((d.data()['correctCount'] as num?)?.toDouble() ?? 0) / total;
          scored++;
        }
      }

      return {
        'name': s.data()['name'] ?? s.id,
        'mathDone': mathDone,
        'mathAvg': scored == 0 ? null : (scoreSum / scored * 100).round(),
        'writing': results[1]
            .docs
            .where((d) => d.data()['isSubmitted'] == true)
            .length,
        'selfCheck':
            results[2].docs.where((d) => d.data()['allDone'] == true).length,
        'exercise': results[3]
            .docs
            .where((d) => (d.data()['entries'] as List? ?? []).isNotEmpty)
            .length,
        'emotion': results[4].docs.length,
      };
    }));

    rows.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return rows;
  }

  // ---------- 지역별 비식별 통계 (관리자용) ----------
  Future<List<Map<String, dynamic>>> fetchRegionStats({int days = 7}) async {
    final snap = await _db
        .collection('regionStats')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(days)
        .get();
    return snap.docs
        .map((d) => {'date': d.id, ...d.data()})
        .toList();
  }

  // ---------- 개념 분석 (교사용) ----------
  /// 학급 전체의 수학 오답 태그를 집계해 취약 개념 순위를 반환.
  /// 반환 형식: [{tag, wrongCount, studentNames(Set)}...] 오답 많은 순.
  Future<List<Map<String, dynamic>>> fetchConceptStats(String classId) async {
    final students = await _db.collection('classes/$classId/students').get();
    final tagWrong = <String, int>{};
    final tagStudents = <String, Set<String>>{};

    await Future.wait(students.docs.map((s) async {
      final progress = await _db
          .collection('classes/$classId/students/${s.id}/mathProgress')
          .get();
      for (final doc in progress.docs) {
        for (final tag in List<String>.from(doc.data()['wrongTags'] ?? [])) {
          tagWrong[tag] = (tagWrong[tag] ?? 0) + 1;
          (tagStudents[tag] ??= {}).add(s.data()['name'] ?? s.id);
        }
      }
    }));

    final stats = tagWrong.entries
        .map((e) => {
              'tag': e.key,
              'wrongCount': e.value,
              'studentNames': tagStudents[e.key] ?? <String>{},
            })
        .toList()
      ..sort((a, b) =>
          (b['wrongCount'] as int).compareTo(a['wrongCount'] as int));
    return stats;
  }
}
