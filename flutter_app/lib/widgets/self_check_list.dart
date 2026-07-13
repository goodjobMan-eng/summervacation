import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 일일 자기 점검 체크리스트 (Self-Check Mission)
///
/// - 선생님이 부여한 당일 항목(classes/{classId}/selfCheckTemplates/{dateKey})과
///   내 진행 상황을 화면을 열 때 1회만 읽고, 이후에는 로컬 상태로 동작한다.
///   (상시 리스너 없음 — 체크할 때만 서버에 씀)
/// - 모든 항목 완료 시 allDone = true 로 기록되어 스케줄러 검사 대상에서 제외된다.
class SelfCheckList extends StatefulWidget {
  final String classId;
  final String studentUid;
  final String dateKey; // 예: "2026-07-20"

  const SelfCheckList({
    super.key,
    required this.classId,
    required this.studentUid,
    required this.dateKey,
  });

  @override
  State<SelfCheckList> createState() => _SelfCheckListState();
}

class _SelfCheckListState extends State<SelfCheckList> {
  List<Map<String, dynamic>>? _items;
  Set<String> _checked = {};

  DocumentReference<Map<String, dynamic>> get _templateRef =>
      FirebaseFirestore.instance
          .doc('classes/${widget.classId}/selfCheckTemplates/${widget.dateKey}');

  DocumentReference<Map<String, dynamic>> get _progressRef =>
      FirebaseFirestore.instance.doc(
          'classes/${widget.classId}/students/${widget.studentUid}/selfChecks/${widget.dateKey}');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_templateRef.get(), _progressRef.get()]);
    if (!mounted) return;
    setState(() {
      _items = List<Map<String, dynamic>>.from(
          results[0].data()?['items'] ?? []);
      _checked =
          Set<String>.from(results[1].data()?['checkedItemIds'] ?? []);
    });
  }

  Future<void> _toggle(String id) async {
    setState(() {
      _checked.contains(id) ? _checked.remove(id) : _checked.add(id);
    });
    // 체크하는 순간에만 서버에 기록 (리스너 없이 단방향 쓰기)
    await _progressRef.set({
      'checkedItemIds': _checked.toList(),
      'allDone': _checked.length == _items!.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(child: Text('오늘은 선생님이 내주신 점검 항목이 없어요 🙌'));
    }
    final progress = _checked.length / items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '오늘의 자기 점검 (${_checked.length}/${items.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              if (progress == 1.0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('🌟 오늘의 자기 점검 완료! 멋져요!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final id = items[i]['id'] as String;
              return CheckboxListTile(
                title: Text(items[i]['label'] as String),
                value: _checked.contains(id),
                onChanged: (_) => _toggle(id),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }
}
