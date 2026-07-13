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
/// 한 번 입장하면 로그아웃 전까지 자동 로그인이 유지된다.
class StudentHomeScreen extends StatelessWidget {
  final AppUser user;
  const StudentHomeScreen({super.key, required this.user});

  /// 익명 계정이므로 로그아웃하면 같은 계정으로 다시 들어올 수 없다.
  /// 실수 방지를 위해 확인 후 진행.
  static Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 로그아웃할까요?'),
        content: const Text(
            '로그아웃하면 다음에 참여 코드와 비밀번호로 새로 들어와야 해요.\n'
            '지금까지의 기록은 선생님 화면에 안전하게 남아 있어요.'),
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
    final fs = FirestoreService.instance;
    return FutureBuilder<SchoolClass>(
      future: fs.getClass(user.classId!),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final cls = snap.data!;
        final day = cls.currentMissionDay;

        return Scaffold(
          appBar: AppBar(
            title: Text('${cls.name} · ${user.name}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _NotificationScreen(classId: user.classId!),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (_) => _confirmLogout(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'logout', child: Text('로그아웃')),
                ],
              ),
            ],
          ),
          body: ListView(
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
                enabled: day >= 1 && day <= 28,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MathMissionScreen(day: day)),
                ),
              ),
              _MissionTile(
                emoji: '✍️',
                title: '30일 주제 글쓰기',
                subtitle: '연속 제출에 도전해요!',
                enabled: day >= 1 && day <= 30,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WritingScreen(
                        classId: user.classId!, currentDay: day),
                  ),
                ),
              ),
              _MissionTile(
                emoji: '✅',
                title: '자기 점검 체크리스트',
                subtitle: '오늘의 할 일을 스스로 점검해요',
                enabled: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('자기 점검')),
                      body: SelfCheckList(
                        classId: user.classId!,
                        studentUid: user.uid,
                        dateKey: fs.dateKey(),
                      ),
                    ),
                  ),
                ),
              ),
              _MissionTile(
                emoji: '🏃',
                title: '오늘의 운동 기록',
                subtitle: '맨몸 운동, 달리기, 스포츠… 몸을 움직여요!',
                enabled: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ExerciseScreen(classId: user.classId!),
                  ),
                ),
              ),
              _MissionTile(
                emoji: '💛',
                title: '오늘 기분 다시 알려주기',
                subtitle: '기분이 바뀌면 언제든지 다시 눌러요',
                enabled: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmotionCheckInScreen(
                      classId: user.classId!,
                      popOnDone: true,
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

class _MissionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _MissionTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: enabled,
        leading: Text(emoji, style: const TextStyle(fontSize: 32)),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
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
