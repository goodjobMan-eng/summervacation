import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

/// 운동 종류별 입력 방식 정의
class _ExerciseCategory {
  final String id;
  final String emoji;
  final String name;
  final String inputType; // 'text' | 'number' | 'sport'
  final String hint;
  final String unit; // number 타입의 단위

  const _ExerciseCategory({
    required this.id,
    required this.emoji,
    required this.name,
    required this.inputType,
    required this.hint,
    this.unit = '',
  });
}

const _categories = [
  _ExerciseCategory(
      id: 'bodyweight', emoji: '💪', name: '맨몸 운동', inputType: 'text',
      hint: '예: 팔굽혀펴기 20개, 스쿼트 30개, 플랭크 1분'),
  _ExerciseCategory(
      id: 'running', emoji: '🏃', name: '달리기', inputType: 'number',
      hint: '뛴 거리를 입력해요', unit: 'km'),
  _ExerciseCategory(
      id: 'sports', emoji: '⚽', name: '스포츠', inputType: 'sport',
      hint: '어떤 운동을 몇 분 했나요?'),
  _ExerciseCategory(
      id: 'bike', emoji: '🚴', name: '자전거', inputType: 'number',
      hint: '탄 거리를 입력해요', unit: 'km'),
  _ExerciseCategory(
      id: 'jumprope', emoji: '🤸', name: '줄넘기', inputType: 'number',
      hint: '넘은 횟수를 입력해요', unit: '개'),
  _ExerciseCategory(
      id: 'etc', emoji: '🏊', name: '기타 운동', inputType: 'text',
      hint: '예: 수영 30분, 등산, 배드민턴 연습'),
];

const _sports = ['축구', '농구', '야구', '배드민턴', '피구', '탁구', '수영', '태권도'];

/// 오늘의 운동 기록 — 종류를 골라 종류별 방식으로 기록한다.
/// 하루에 여러 종목을 기록할 수 있고, 기록이 1개 이상이면 미션 완료.
class ExerciseScreen extends StatefulWidget {
  final String classId;
  const ExerciseScreen({super.key, required this.classId});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  _ExerciseCategory _selected = _categories.first;
  String? _selectedSport;
  final _textController = TextEditingController();
  final _numberController = TextEditingController();
  final _minutesController = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>>? _entries; // 1회 조회 후 로컬 관리

  @override
  void initState() {
    super.initState();
    FirestoreService.instance
        .getTodayExercises(widget.classId)
        .then((list) => mounted ? setState(() => _entries = list) : null);
  }

  bool get _canSubmit {
    switch (_selected.inputType) {
      case 'text':
        return _textController.text.trim().isNotEmpty;
      case 'number':
        return double.tryParse(_numberController.text.trim()) != null;
      case 'sport':
        return _selectedSport != null &&
            int.tryParse(_minutesController.text.trim()) != null;
    }
    return false;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final entry = <String, dynamic>{
        'categoryId': _selected.id,
        'categoryName': _selected.name,
        'emoji': _selected.emoji,
        'recordedAt': DateTime.now().toIso8601String(),
      };
      switch (_selected.inputType) {
        case 'text':
          entry['detail'] = _textController.text.trim();
        case 'number':
          entry['value'] = double.parse(_numberController.text.trim());
          entry['unit'] = _selected.unit;
        case 'sport':
          entry['sport'] = _selectedSport;
          entry['minutes'] = int.parse(_minutesController.text.trim());
      }
      await FirestoreService.instance
          .addExerciseEntry(widget.classId, entry);
      _textController.clear();
      _numberController.clear();
      _minutesController.clear();
      setState(() {
        _selectedSport = null;
        (_entries ??= []).add(entry); // 서버 재조회 없이 로컬 갱신
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('운동 기록이 저장되었습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _entryLabel(Map<String, dynamic> e) {
    if (e['detail'] != null) return e['detail'];
    if (e['value'] != null) return '${e['value']} ${e['unit'] ?? ''}';
    if (e['sport'] != null) return '${e['sport']} ${e['minutes']}분';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운동 기록')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 운동 종류 선택 ----
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final on = _selected.id == c.id;
              return ChoiceChip(
                avatar: Text(c.emoji, style: const TextStyle(fontSize: 18)),
                label: Text(c.name),
                selected: on,
                onSelected: (_) => setState(() {
                  _selected = c;
                  _selectedSport = null;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ---- 종류별 입력 폼 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_selected.emoji} ${_selected.name}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(_selected.hint,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  if (_selected.inputType == 'text')
                    TextField(
                      controller: _textController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: '무엇을 얼마나 했나요?',
                          hintText: _selected.hint),
                    ),
                  if (_selected.inputType == 'number')
                    TextField(
                      controller: _numberController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                          labelText: '기록 (${_selected.unit})',
                          hintText: '예: 1.5'),
                    ),
                  if (_selected.inputType == 'sport') ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sports
                          .map((s) => ChoiceChip(
                                label: Text(s),
                                selected: _selectedSport == s,
                                onSelected: (_) =>
                                    setState(() => _selectedSport = s),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _minutesController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '운동한 시간 (분)', hintText: '예: 30'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canSubmit && !_busy ? _submit : null,
                      child: Text(_busy ? '기록 중...' : '기록하기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 오늘 기록 목록 ----
          Text('오늘 내가 한 운동',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final entries = _entries;
              if (entries == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (entries.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('아직 기록이 없어요. 오늘 몸을 움직여 볼까요? 💪',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              return Column(
                children: entries
                    .map((e) => Card(
                          child: ListTile(
                            leading: Text(e['emoji'] ?? '🏃',
                                style: const TextStyle(fontSize: 26)),
                            title: Text(e['categoryName'] ?? ''),
                            subtitle: Text(_entryLabel(e)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: '기록 삭제',
                              onPressed: () async {
                                await FirestoreService.instance
                                    .removeExerciseEntry(widget.classId, e);
                                setState(() => _entries!.remove(e));
                              },
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
