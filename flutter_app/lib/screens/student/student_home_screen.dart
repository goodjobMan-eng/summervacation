import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../widgets/self_check_list.dart';
import 'emotion_checkin_screen.dart';
import 'exercise_screen.dart';
import 'math_mission_screen.dart';
import 'writing_screen.dart';

/// 학생 홈 — 오늘의 5대 미션 진입점 + 알림
///
/// 미션 완료 여부(✔)는 실시간 연동 없이 동작한다:
///  - 홈을 열 때 내 오늘 기록을 1회 읽어 표시하고,
///  - 미션 화면을 다녀올 때마다 다시 1회 읽어 갱신한다.
///  → 문제를 다 풀고 돌아오면 그 즉시 타일에 체크가 나타난다.
class StudentHomeScreen extends StatefulWidget {
  final AppUser user;
  const StudentHomeScreen({super.key, required this.user});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  SchoolClass? _cls;
  Map<String, bool> _done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fs = FirestoreService.instance;
    final cls = _cls ?? await fs.getClass(widget.user.classId!);
    final done =
        await fs.getMyDailyStatus(widget.user.classId!, cls.currentMissionDay);
    if (!mounted) return;
    setState(() {
      _cls = cls;
      _done = done;
    });
  }

  /// 미션 화면을 다녀오면 완료 현황을 1회만 다시 읽는다
  Future<void> _open(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  /// 익명 계정이므로 로그아웃하면 같은 계정으로 다시 들어올 수 없다.
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 로그아웃할까요?'),
        content: const Text(
            '로그아웃하면 다음에 참여 코드와 비밀번호로 새로 들어와야 해요.\n'
            '지금까지의 기록은 안전하게 남아 있어요.'),
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
  }

  @override
  Widget build(BuildContext context) {
    final cls = _cls;
    if (cls == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = cls.currentMissionDay;
    final fs = FirestoreService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('${cls.name} · ${widget.user.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _open(
                _NotificationScreen(classId: widget.user.classId!)),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _confirmLogout(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('로그아웃')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  day >= 1
                      ? '📅 방학 미션 $day일차'
                      : '방학 미션이 아직 시작되지 않았어요!',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _MissionTile(
              emoji: '📐',
              title: '오늘의 수학',
              subtitle: '6학년 1학기 맞춤 학습 (28일)',
              done: _done['math'] == true,
              enabled: day >= 1 && day <= 28,
              onTap: () => _open(MathMissionScreen(day: day)),
            ),
            _MissionTile(
              emoji: '✍️',
              title: '30일 주제 글쓰기',
              subtitle: '연속 제출에 도전해요!',
              done: _done['writing'] == true,
              enabled: day >= 1 && day <= 30,
              onTap: () => _open(WritingScreen(
                  classId: widget.user.classId!, currentDay: day)),
            ),
            _MissionTile(
              emoji: '✅',
              title: '자기 점검 체크리스트',
              subtitle: '오늘의 할 일을 스스로 점검해요',
              done: _done['selfCheck'] == true,
              enabled: true,
              onTap: () => _open(Scaffold(
                appBar: AppBar(title: const Text('자기 점검')),
                body: SelfCheckList(
                  classId: widget.user.classId!,
                  studentUid: widget.user.uid,
                  dateKey: fs.dateKey(),
                ),
              )),
            ),
            _MissionTile(
              emoji: '🏃',
              title: '오늘의 운동 기록',
              subtitle: '맨몸 운동, 달리기, 스포츠… 몸을 움직여요!',
              done: _done['exercise'] == true,
              enabled: true,
              onTap: () =>
                  _open(ExerciseScreen(classId: widget.user.classId!)),
            ),
            _MissionTile(
              emoji: '💛',
              title: '오늘 기분 다시 알려주기',
              subtitle: '기분이 바뀌면 언제든지 다시 눌러요',
              done: false,
              enabled: true,
              onTap: () => _open(EmotionCheckInScreen(
                  classId: widget.user.classId!, popOnDone: true)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool done;
  final VoidCallback onTap;

  const _MissionTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: done ? const Color(0xFFDDF2EC) : null,
      shape: done
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF3FA98E)),
            )
          : null,
      child: ListTile(
        enabled: enabled,
        leading: Text(emoji, style: const TextStyle(fontSize: 32)),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(done ? '오늘 미션 완료! 🎉' : subtitle),
        trailing: done
            ? const Icon(Icons.check_circle, color: Color(0xFF3FA98E))
            : const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

/// 스케줄러가 notifications 배열에 삽입한 알림 목록 (열 때 1회만 조회)
class _NotificationScreen extends StatelessWidget {
  final String classId;
  const _NotificationScreen({required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: FirestoreService.instance.getMyNotifications(classId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = List<Map<String, dynamic>>.from(snap.data!)
            ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
          if (items.isEmpty) {
            return const Center(child: Text('알림이 없어요 🎉'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = MissionNotification.fromMap(items[i]);
              return ListTile(
                leading: Text(
                  switch (n.type) {
                    'math' => '📐',
                    'writing' => '✍️',
                    'selfCheck' => '✅',
                    'exercise' => '🏃',
                    'reminder' => '📣',
                    _ => '😊',
                  },
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(n.message),
                subtitle: Text(n.date),
              );
            },
          );
        },
      ),
    );
  }
}
