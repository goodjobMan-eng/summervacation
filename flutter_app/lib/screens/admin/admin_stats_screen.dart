import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

/// 앱 관리자용 지역별 비식별 통계 화면
///
/// - 이름·학교·개인 정보 없이 "지역 단위" 집계만 표시한다.
/// - 데이터는 매일 밤 Cloud Function(aggregateRegionStats)이 만들고,
///   Rules상 role == 'admin' 계정만 읽을 수 있다.
///   (admin 지정: Firestore 콘솔에서 users/{내 uid}.role = 'admin')
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirestoreService.instance.fetchRegionStats(days: 7);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지역별 통계 (비식별)')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {
          _future = FirestoreService.instance.fetchRegionStats(days: 7);
        }),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final days = snap.data!;
            if (days.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                      child: Text(
                          '아직 집계된 통계가 없어요.\n매일 밤 21:30에 자동 집계됩니다.',
                          textAlign: TextAlign.center)),
                ),
              ]);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '🔒 개인을 식별할 수 없는 지역 단위 집계입니다.\n'
                      '최근 7일치가 표시되며, 아래로 당기면 새로고침됩니다.',
                      style: TextStyle(height: 1.5, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...days.map((day) => _DayCard(day: day)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final Map<String, dynamic> day;
  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final regions = Map<String, dynamic>.from(day['regions'] ?? {});
    final entries = regions.entries.toList()
      ..sort((a, b) => (b.value['students'] as num)
          .compareTo(a.value['students'] as num));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 ${day['date']}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('이 날은 활동 데이터가 없어요.',
                  style: TextStyle(color: Colors.grey)),
            ...entries.map((e) {
              final r = Map<String, dynamic>.from(e.value);
              final students = (r['students'] as num?)?.toInt() ?? 0;
              final exercised = (r['exercised'] as num?)?.toInt() ?? 0;
              final checkedIn = (r['checkedIn'] as num?)?.toInt() ?? 0;
              final positive = (r['positive'] as num?)?.toInt() ?? 0;
              final neutral = (r['neutral'] as num?)?.toInt() ?? 0;
              final negative = (r['negative'] as num?)?.toInt() ?? 0;
              final exRate =
                  students == 0 ? 0 : (exercised / students * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key} · 학생 $students명',
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('🏃 운동 ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: students == 0 ? 0 : exercised / students,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$exRate%',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 감정 분포: 긍정/보통/부정 스택 바
                    Row(
                      children: [
                        const Text('💛 정서 ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: checkedIn == 0
                              ? Text(' 체크인 없음',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    children: [
                                      if (positive > 0)
                                        _moodBar(positive,
                                            Colors.green.shade400),
                                      if (neutral > 0)
                                        _moodBar(neutral,
                                            Colors.amber.shade400),
                                      if (negative > 0)
                                        _moodBar(negative,
                                            Colors.red.shade300),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Text('😊$positive 😐$neutral 😢$negative',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _moodBar(int count, Color color) =>
      Expanded(flex: count, child: Container(height: 8, color: color));
}
