import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../widgets/streak_tracker.dart';
import '../../theme.dart';

/// 30일 주제 글쓰기 — 오늘의 주제 + 작성/제출 + Streak 트래커
class WritingScreen extends StatefulWidget {
  final String classId;
  final int currentDay;

  const WritingScreen({
    super.key,
    required this.classId,
    required this.currentDay,
  });

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  late Future<Set<int>> _submittedDays; // 1회 조회 (상시 리스너 없음)

  static const _minLength = 100; // 6학년 수준: 최소 100자

  @override
  void initState() {
    super.initState();
    _submittedDays =
        FirestoreService.instance.getSubmittedWritingDays(widget.classId);
  }

  Future<void> _submit() async {
    if (_controller.text.trim().length < _minLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생각을 조금 더 풀어서 100자 이상 써 보세요! ✏️')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await FirestoreService.instance
          .submitWriting(widget.currentDay, _controller.text);
      if (mounted) {
        setState(() {
          // 제출 직후에만 트래커를 한 번 갱신
          _submittedDays = FirestoreService.instance
              .getSubmittedWritingDays(widget.classId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 오늘의 글쓰기 제출 완료!')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('30일 주제 글쓰기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 연속 제출(Streak) 트래커 — 1회 조회, 제출 시에만 갱신
          FutureBuilder<Set<int>>(
            future: _submittedDays,
            builder: (context, snap) => StreakTracker(
              submittedDays: snap.data ?? {},
              currentDay: widget.currentDay,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<WritingTopic?>(
            future: fs.getWritingTopic(widget.currentDay),
            builder: (context, snap) {
              final topic = snap.data;
              if (topic == null) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('오늘의 주제가 아직 등록되지 않았어요.'),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: AppColors.primarySoft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Day ${topic.day} 주제',
                              style:
                                  Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(topic.topic,
                              style:
                                  Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(topic.guide,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 12,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '여기에 글을 써 보세요. (100자 이상)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 4),
                    child: Text(
                      '${_controller.text.trim().length} / $_minLength자',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: _controller.text.trim().length >= _minLength
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_busy ? '제출 중...' : '제출하기'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
