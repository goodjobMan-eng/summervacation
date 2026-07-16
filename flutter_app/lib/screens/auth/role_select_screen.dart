import 'package:flutter/material.dart';

import '../../theme.dart';
import 'join_class_screen.dart';
import 'teacher_create_class_screen.dart';

/// 앱 첫 화면 — 선생님/학생 역할 선택
/// 여러 학교의 6학년 선생님들에게 배포되는 것을 전제로,
/// 선생님은 학급을 개설하고 학생은 코드+비밀번호로 입장한다.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.menu_book_outlined,
                      size: 34, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text('여름방학 숙제',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('6학년 여름방학 학습·생활 기록 서비스',
                    style: TextStyle(color: AppColors.inkSoft)),
                const SizedBox(height: 36),
                _RoleCard(
                  icon: Icons.co_present_outlined,
                  title: '선생님으로 시작',
                  subtitle: '우리 반 학급을 개설하고\n참여 코드와 비밀번호를 받아요',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TeacherCreateClassScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  icon: Icons.backpack_outlined,
                  title: '학생으로 시작',
                  subtitle: '선생님께 받은 참여 코드와\n비밀번호로 우리 반에 들어가요',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const JoinClassScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey, height: 1.4)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
