import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme.dart';

/// 주제 글쓰기 모아보기 (교사용)
/// 일차를 골라 학급 전체 학생의 글을 한 화면에서 한 번에 확인한다.
class WritingReviewScreen extends StatefulWidget {
  final String classId;
  final int initialDay;

  const WritingReviewScreen({
    super.key,
    required this.classId,
    required this.initialDay,
  });

  @override
  State<WritingReviewScreen> createState() => _WritingReviewScreenState();
}

class _WritingReviewScreenState extends State<WritingReviewScreen> {
  late int _day;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay.clamp(1, 30);
    _fetch();
  }

  void _fetch() {
    _future = FirestoreService.instance
        .fetchWritingSubmissions(widget.classId, _day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기 모아보기'),
        actions: [
          // 일차 선택
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<int>(
              value: _day,
              underline: const SizedBox.shrink(),
              items: List.generate(30, (i) => i + 1)
                  .map((d) => DropdownMenuItem(
                      value: d, child: Text('$d일차')))
                  .toList(),
              onChanged: (d) => setState(() {
                _day = d!;
                _fetch();
              }),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('아직 가입한 학생이 없어요.'));
          }
          final submitted =
              rows.where((r) => r['isSubmitted'] == true).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppColors.primarySoft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      '$_day일차 제출 현황: $submitted / ${rows.length}명',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              const SizedBox(height: 8),
              ...rows.map((r) {
                final isSubmitted = r['isSubmitted'] == true;
                return Card(
                  child: ExpansionTile(
                    leading: Icon(
                        isSubmitted
                            ? Icons.description_outlined
                            : Icons.hourglass_empty,
                        color: isSubmitted
                            ? AppColors.primary
                            : AppColors.inkSoft),
                    title: Text(r['name'],
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      isSubmitted
                          ? '${(r['content'] as String).length}자 제출'
                          : '미제출',
                      style: TextStyle(
                          color: isSubmitted
                              ? Colors.green.shade700
                              : Colors.grey),
                    ),
                    children: [
                      if (isSubmitted)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(r['content'],
                                style: const TextStyle(height: 1.7)),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('아직 제출하지 않았어요.'),
                        ),
                    ],
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
