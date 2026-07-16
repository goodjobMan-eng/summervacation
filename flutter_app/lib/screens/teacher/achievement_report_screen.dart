import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/firestore_service.dart';

/// 방학 과제 달성도 리포트 (교사용)
/// 학급 전체 학생의 과제 달성도를 표로 보여주고,
/// CSV로 복사해 엑셀/한글 등에 붙여넣어 한번에 뽑을 수 있다.
class AchievementReportScreen extends StatefulWidget {
  final String classId;
  final String className;
  const AchievementReportScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<AchievementReportScreen> createState() =>
      _AchievementReportScreenState();
}

class _AchievementReportScreenState extends State<AchievementReportScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        FirestoreService.instance.fetchAchievementReport(widget.classId);
  }

  String _toCsv(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer(
        '이름,수학 완료(일),수학 평균 정답률(%),글쓰기 제출(일),자기점검 완료(일),운동 기록(일),감정 체크인(일)\n');
    for (final r in rows) {
      buffer.writeln(
          '${r['name']},${r['mathDone']},${r['mathAvg'] ?? '-'},${r['writing']},${r['selfCheck']},${r['exercise']},${r['emotion']}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.className} 달성도 리포트')),
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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('학생 ${rows.length}명 · 방학 전체 기간 집계',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.copy_all, size: 18),
                      label: const Text('CSV 복사'),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _toCsv(rows)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  '표 전체를 복사했어요. 엑셀이나 한글에 붙여넣으세요!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DataTable(
                      headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                      columns: const [
                        DataColumn(label: Text('이름')),
                        DataColumn(label: Text('수학\n(완료일)')),
                        DataColumn(label: Text('수학\n(평균 %)')),
                        DataColumn(label: Text('글쓰기\n(제출일)')),
                        DataColumn(label: Text('자기점검\n(완료일)')),
                        DataColumn(label: Text('운동\n(기록일)')),
                        DataColumn(label: Text('감정\n(체크인)')),
                      ],
                      rows: rows
                          .map((r) => DataRow(cells: [
                                DataCell(Text(r['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text('${r['mathDone']}/28')),
                                DataCell(Text(r['mathAvg'] == null
                                    ? '-'
                                    : '${r['mathAvg']}%')),
                                DataCell(Text('${r['writing']}/30')),
                                DataCell(Text('${r['selfCheck']}일')),
                                DataCell(Text('${r['exercise']}일')),
                                DataCell(Text('${r['emotion']}일')),
                              ]))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
