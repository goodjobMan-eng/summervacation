import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/math_curriculum.dart';
import '../../data/writing_topics.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학급 대시보드')),
      body: switch (_tab) {
        0 => _DailyStatusTab(classId: widget.classId),
        1 => const _ContentBankTab(),
        _ => _SelfCheckTemplateTab(classId: widget.classId),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: '오늘 현황'),
          NavigationDestination(
              icon: Icon(Icons.library_books_outlined), label: '문제 은행'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined), label: '자기 점검 부여'),
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
                        Text('참여 코드: ${cls.joinCode} · 학생 ${students.length}명'),
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

  Future<void> _sendReminder(
      BuildContext context, Map<String, dynamic> status) async {
    final missing = <String>[
      if (status['math'] != true) '수학',
      if (status['writing'] != true) '글쓰기',
      if (status['selfCheck'] != true) '자기 점검',
      if (status['emotionEmoji'] == null) '감정 체크인',
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
            status['emotionEmoji'] != null;

        return Card(
          child: ListTile(
            leading: Text(
              status['emotionEmoji'] ?? '❔',
              style: const TextStyle(fontSize: 30),
            ),
            title: Text(name),
            subtitle: (status['emotionComment'] ?? '').isEmpty
                ? null
                : Text('💬 ${status['emotionComment']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MissionDot(label: '수학', done: status['math'] == true),
                _MissionDot(label: '글', done: status['writing'] == true),
                _MissionDot(label: '점검', done: status['selfCheck'] == true),
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
// 탭 2: 동학년 공동 문제 은행 관리
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
