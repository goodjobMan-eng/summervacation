import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/math_curriculum.dart';
import '../../data/writing_topics.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import 'achievement_report_screen.dart';
import 'writing_review_screen.dart';

/// 선생님용 학급 대시보드 (Teacher Portal)
///  - 탭 1: 본인 학급 학생들의 당일 4대 미션 현황 + 감정 상태 모니터링
///  - 탭 2: 동학년 공동 문제 은행 관리 (수학 28일 / 글쓰기 30일 시드 업로드)
///  - 탭 3: 오늘의 자기 점검 항목 부여
class TeacherDashboardScreen extends StatefulWidget {
  final String classId;
  const TeacherDashboardScreen({super.key, required this.classId});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _ensureSeedData();
  }

  /// 문제 은행이 비어 있으면(첫 사용) 수학 28일×10문제와
  /// 글쓰기 30일 주제를 자동으로 업로드한다 — 버튼을 누를 필요 없음.
  Future<void> _ensureSeedData() async {
    final db = FirebaseFirestore.instance;
    final probe = await db.doc('mathBank/day01').get();
    if (probe.exists) return;

    final batch = db.batch();
    for (final day in kMathCurriculumSeed) {
      final dayId = 'day${day['day'].toString().padLeft(2, '0')}';
      batch.set(db.doc('mathBank/$dayId'), day, SetOptions(merge: true));
    }
    for (final topic in kWritingTopicsSeed) {
      final dayId = 'day${topic['day'].toString().padLeft(2, '0')}';
      batch.set(
          db.doc('writingTopics/$dayId'), topic, SetOptions(merge: true));
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('📚 기본 문제 은행(수학 280문제 + 글쓰기 30주제)을 준비했어요!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학급 대시보드'),
        actions: [
          IconButton(
            tooltip: '과제 달성도 리포트 (방학 종료 후 일괄 출력)',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () async {
              final cls =
                  await FirestoreService.instance.getClass(widget.classId);
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AchievementReportScreen(
                    classId: widget.classId,
                    className: cls.name,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (_) async {
              // 익명 계정이므로 로그아웃하면 이 기기에서 학급 관리 권한을
              // 다시 얻을 수 없음 — 반드시 확인 후 진행
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('정말 로그아웃할까요?'),
                  content: const Text(
                      '⚠️ 로그아웃하면 이 브라우저에서 학급 관리 계정에 다시 '
                      '접속할 수 없습니다.\n학급 운영 기간에는 로그아웃하지 않는 것을 권장합니다.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('로그아웃')),
                  ],
                ),
              );
              if (ok == true) await FirebaseAuth.instance.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('로그아웃')),
            ],
          ),
        ],
      ),
      body: switch (_tab) {
        0 => _DailyStatusTab(classId: widget.classId),
        1 => _ConceptStatsTab(classId: widget.classId),
        2 => const _ContentBankTab(),
        _ => _SelfCheckTemplateTab(classId: widget.classId),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: '오늘 현황'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), label: '개념 분석'),
          NavigationDestination(
              icon: Icon(Icons.library_books_outlined), label: '문제 은행'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined), label: '자기 점검'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// 탭 1: 당일 미션 현황 실시간 모니터링 + 미완료 학생 알림 발송
//  - 학생 목록과 학생별 4대 미션 문서를 모두 스트림으로 구독하므로
//    학생이 과제를 제출하는 순간 대시보드에 즉시 반영된다.
// ---------------------------------------------------------------------
class _DailyStatusTab extends StatefulWidget {
  final String classId;
  const _DailyStatusTab({required this.classId});

  @override
  State<_DailyStatusTab> createState() => _DailyStatusTabState();
}

class _DailyStatusTabState extends State<_DailyStatusTab> {
  bool _sending = false;

  Future<void> _sendBulkReminders(int missionDay) async {
    setState(() => _sending = true);
    try {
      final sent = await FirestoreService.instance
          .sendRemindersToIncomplete(widget.classId, missionDay);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(sent > 0
                  ? '📣 미완료 학생 $sent명에게 알림을 보냈어요.'
                  : '🎉 모든 학생이 오늘 미션을 완료했어요!')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return FutureBuilder<SchoolClass>(
      future: fs.getClass(widget.classId),
      builder: (context, classSnap) {
        if (!classSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cls = classSnap.data!;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fs.watchClassStudents(widget.classId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final students = snap.data!.docs;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _EmotionAlertBanner(classId: widget.classId),
                Card(
                  color: Colors.indigo.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${cls.name} · 미션 ${cls.currentMissionDay}일차',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .doc('classes/${widget.classId}/private/credentials')
                              .snapshots(),
                          builder: (context, credSnap) {
                            final pw = credSnap.data?.data()?['password'];
                            return Text(
                                '참여 코드: ${cls.joinCode}${pw != null ? ' · 비밀번호: $pw' : ''} · 학생 ${students.length}명');
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.campaign_outlined),
                            label: Text(_sending
                                ? '발송 중...'
                                : '미완료 학생 전체에게 알림 보내기'),
                            onPressed: _sending
                                ? null
                                : () =>
                                    _sendBulkReminders(cls.currentMissionDay),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.menu_book_outlined),
                            label: const Text('주제 글쓰기 모아보기'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WritingReviewScreen(
                                  classId: widget.classId,
                                  initialDay: cls.currentMissionDay,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...students.map((s) => _StudentStatusRow(
                      classId: widget.classId,
                      studentUid: s.id,
                      name: s.data()['name'] ?? '',
                      missionDay: cls.currentMissionDay,
                    )),
                if (students.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('아직 가입한 학생이 없어요.')),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 감정 위기 경고 배너 — Cloud Function이 부정적 감정 반복을 감지하면
/// 여기에 실시간으로 표시된다. '확인'을 누르면 read 처리되어 사라진다.
class _EmotionAlertBanner extends StatelessWidget {
  final String classId;
  const _EmotionAlertBanner({required this.classId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.instance.watchTeacherAlerts(classId),
      builder: (context, snap) {
        final alerts = snap.data?.docs ?? [];
        if (alerts.isEmpty) return const SizedBox.shrink();

        return Column(
          children: alerts.map((doc) {
            final a = doc.data();
            return Card(
              color: const Color(0xFFFFF0F0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFFFB4A9), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a['message'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    if ((a['reason'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 32),
                        child: Text('이유: ${a['emoji'] ?? ''} ${a['reason']}'),
                      ),
                    if ((a['comment'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 32),
                        child: Text('💬 "${a['comment']}"',
                            style: TextStyle(color: Colors.grey.shade700)),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => FirestoreService.instance
                            .markAlertRead(classId, doc.id),
                        child: const Text('확인했어요'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// 학생 한 명의 실시간 미션 현황 행 + 개별 알림 버튼
class _StudentStatusRow extends StatelessWidget {
  final String classId;
  final String studentUid;
  final String name;
  final int missionDay;

  const _StudentStatusRow({
    required this.classId,
    required this.studentUid,
    required this.name,
    required this.missionDay,
  });

  /// 기분 이유 + 코멘트를 한 줄 요약으로 표시
  Widget? _buildEmotionSubtitle(Map<String, dynamic> status) {
    final parts = <String>[
      if ((status['emotionReason'] ?? '').isNotEmpty) status['emotionReason'],
      if ((status['emotionComment'] ?? '').isNotEmpty)
        '💬 ${status['emotionComment']}',
    ];
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '),
        maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  Future<void> _sendReminder(
      BuildContext context, Map<String, dynamic> status) async {
    final missing = <String>[
      if (status['math'] != true) '수학',
      if (status['writing'] != true) '글쓰기',
      if (status['selfCheck'] != true) '자기 점검',
      if (status['emotionEmoji'] == null) '감정 체크인',
      if (status['exercise'] != true) '운동',
    ];
    if (missing.isEmpty) return;
    await FirestoreService.instance.sendReminderToStudent(
      classId,
      studentUid,
      '선생님의 알림: 오늘의 ${missing.join(', ')} 미션을 잊지 마세요! 📣',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📣 $name 학생에게 알림을 보냈어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirestoreService.instance
          .watchStudentDailyStatus(classId, studentUid, missionDay),
      builder: (context, snap) {
        final status = snap.data ??
            {'math': false, 'writing': false, 'selfCheck': false};
        final allDone = status['math'] == true &&
            status['writing'] == true &&
            status['selfCheck'] == true &&
            status['exercise'] == true &&
            status['emotionEmoji'] != null;

        return Card(
          child: ListTile(
            leading: Text(
              status['emotionEmoji'] ?? '❔',
              style: const TextStyle(fontSize: 30),
            ),
            // 최근 3일 중 2일 이상 힘든 기분이면 이름 옆에 상시 배지 표시
            title: FutureBuilder<int>(
              future: FirestoreService.instance
                  .getRecentNegativeDays(classId, studentUid),
              builder: (context, snap) {
                final warn = (snap.data ?? 0) >= 2;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(name)),
                    if (warn)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Tooltip(
                          message: '최근 3일 중 ${snap.data}일 힘든 기분 — 마음을 살펴봐 주세요',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDEBE8),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE4574A)),
                            ),
                            child: const Text('💛 관심',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE4574A))),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            subtitle: _buildEmotionSubtitle(status),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MissionDot(label: '수학', done: status['math'] == true),
                _MissionDot(label: '글', done: status['writing'] == true),
                _MissionDot(label: '점검', done: status['selfCheck'] == true),
                _MissionDot(label: '운동', done: status['exercise'] == true),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: allDone ? '모든 미션 완료!' : '이 학생에게 알림 보내기',
                  icon: Icon(
                    allDone
                        ? Icons.check_circle
                        : Icons.notifications_active_outlined,
                    color: allDone ? Colors.green : Colors.deepOrange,
                  ),
                  onPressed:
                      allDone ? null : () => _sendReminder(context, status),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MissionDot extends StatelessWidget {
  final String label;
  final bool done;
  const _MissionDot({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Colors.green : Colors.grey,
            size: 22,
          ),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// 탭 2: 개념 분석 — 학급 전체의 수학 오답 태그를 집계해 취약 개념 표시
//  문제마다 붙은 개념 태그(tag)를 기준으로, 어떤 개념에서 오답이 많이
//  나오는지 순위·오답 수·해당 학생을 한눈에 보여준다.
// ---------------------------------------------------------------------
class _ConceptStatsTab extends StatefulWidget {
  final String classId;
  const _ConceptStatsTab({required this.classId});

  @override
  State<_ConceptStatsTab> createState() => _ConceptStatsTabState();
}

class _ConceptStatsTabState extends State<_ConceptStatsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirestoreService.instance.fetchConceptStats(widget.classId);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {
        _future =
            FirestoreService.instance.fetchConceptStats(widget.classId);
      }),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snap.data!;
          if (stats.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                      child: Text('아직 오답 데이터가 없어요.\n학생들이 수학 미션을 제출하면 여기에 취약 개념이 표시됩니다.',
                          textAlign: TextAlign.center)),
                ),
              ],
            );
          }
          final maxWrong = stats.first['wrongCount'] as int;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '📊 우리 반 취약 개념 분석\n오답이 많이 나온 개념 순서입니다. 아래로 당기면 새로고침됩니다.',
                    style: TextStyle(height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...stats.map((s) {
                final tag = s['tag'] as String;
                final wrong = s['wrongCount'] as int;
                final students =
                    (s['studentNames'] as Set<String>).toList()..sort();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(tag,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ),
                            Text('오답 $wrong회',
                                style: TextStyle(
                                    color: Colors.deepOrange.shade400,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: wrong / maxWrong,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.deepOrange.shade300,
                          backgroundColor: Colors.orange.shade50,
                        ),
                        const SizedBox(height: 8),
                        Text('어려워한 학생: ${students.join(', ')}',
                            style: const TextStyle(
                                fontSize: 12.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// 탭 3: 동학년 공동 문제 은행 관리
// ---------------------------------------------------------------------
class _ContentBankTab extends StatefulWidget {
  const _ContentBankTab();

  @override
  State<_ContentBankTab> createState() => _ContentBankTabState();
}

class _ContentBankTabState extends State<_ContentBankTab> {
  bool _busy = false;
  String? _message;

  Future<void> _seedMath() async {
    setState(() => _busy = true);
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    for (final day in kMathCurriculumSeed) {
      final dayId = 'day${day['day'].toString().padLeft(2, '0')}';
      batch.set(db.doc('mathBank/$dayId'), day, SetOptions(merge: true));
    }
    await batch.commit();
    setState(() {
      _busy = false;
      _message = '✅ 수학 28일 커리큘럼을 문제 은행에 업로드했습니다.';
    });
  }

  Future<void> _seedWriting() async {
    setState(() => _busy = true);
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    for (final topic in kWritingTopicsSeed) {
      final dayId = 'day${topic['day'].toString().padLeft(2, '0')}';
      batch.set(db.doc('writingTopics/$dayId'), topic, SetOptions(merge: true));
    }
    await batch.commit();
    setState(() {
      _busy = false;
      _message = '✅ 글쓰기 30일 주제를 업로드했습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '동학년 공동 문제 은행은 6학년 모든 선생님이 함께 관리합니다.\n'
          '아래 버튼으로 기본 커리큘럼을 업로드한 뒤, Firestore 콘솔 또는\n'
          '이 화면(추후 편집 UI)에서 문제를 추가/수정할 수 있습니다.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Text('📐', style: TextStyle(fontSize: 30)),
            title: const Text('수학 28일 커리큘럼 초기화'),
            subtitle: const Text('개념 18일 + 혼합 복습 10일'),
            trailing: FilledButton(
              onPressed: _busy ? null : _seedMath,
              child: const Text('업로드'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Text('✍️', style: TextStyle(fontSize: 30)),
            title: const Text('글쓰기 30일 주제 초기화'),
            subtitle: const Text('30-Day Writing Project'),
            trailing: FilledButton(
              onPressed: _busy ? null : _seedWriting,
              child: const Text('업로드'),
            ),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_message!, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// 탭 3: 오늘의 자기 점검 항목 부여
// ---------------------------------------------------------------------
class _SelfCheckTemplateTab extends StatefulWidget {
  final String classId;
  const _SelfCheckTemplateTab({required this.classId});

  @override
  State<_SelfCheckTemplateTab> createState() => _SelfCheckTemplateTabState();
}

class _SelfCheckTemplateTabState extends State<_SelfCheckTemplateTab> {
  final _controller = TextEditingController();

  DocumentReference<Map<String, dynamic>> get _templateRef =>
      FirebaseFirestore.instance.doc(
          'classes/${widget.classId}/selfCheckTemplates/${FirestoreService.instance.dateKey()}');

  Future<void> _addItem(List<Map<String, dynamic>> current) async {
    final label = _controller.text.trim();
    if (label.isEmpty) return;
    final items = [
      ...current,
      {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'label': label},
    ];
    await _templateRef.set({'items': items}, SetOptions(merge: true));
    _controller.clear();
  }

  Future<void> _removeItem(
      List<Map<String, dynamic>> current, String id) async {
    await _templateRef.set(
      {'items': current.where((e) => e['id'] != id).toList()},
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _templateRef.snapshots(),
      builder: (context, snap) {
        final items = List<Map<String, dynamic>>.from(
            snap.data?.data()?['items'] ?? []);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: '오늘의 점검 항목 추가',
                        hintText: '예: 알림장 확인하기, 독서 30분',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addItem(items),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addItem(items),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('오늘 부여한 점검 항목이 없습니다.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.check_box_outlined),
                            title: Text(items[i]['label']),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _removeItem(items, items[i]['id']),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
