import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

/// 오늘의 수학 미션 — 한 문제씩 풀기
///
/// 흐름: 문제 1개 표시 → 답 입력 → [정답 확인] → 맞으면 [다음 문제],
///       틀리면 맞을 때까지 다시 도전 → 10문제를 모두 맞히면 서버에 제출.
/// 한 번이라도 틀렸던 문제는 기록되어 교사 '개념 분석'에 반영된다.
class MathMissionScreen extends StatefulWidget {
  final int day;
  const MathMissionScreen({super.key, required this.day});

  @override
  State<MathMissionScreen> createState() => _MathMissionScreenState();
}

class _MathMissionScreenState extends State<MathMissionScreen> {
  MathDay? _mathDay;
  bool _loading = true;

  int _index = 0;
  final _answers = <String, String>{}; // 정답 확인을 통과한 내 답
  final _wrongOnce = <String>{}; // 한 번이라도 틀린 문제 (개념 분석용)
  final _controller = TextEditingController();
  String? _choice;
  bool _correct = false; // 현재 문제 정답 확인 완료
  bool _showWrong = false; // 오답 피드백 표시
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    FirestoreService.instance.getMathDay(widget.day).then((d) {
      if (mounted) {
        setState(() {
          _mathDay = d;
          _loading = false;
        });
      }
    });
  }

  /// 답 비교 — 공백 무시, 소수는 수치로도 비교 (0.40 == 0.4)
  bool _check(String given, String expected) {
    final g = given.trim().replaceAll(' ', '');
    final e = expected.trim().replaceAll(' ', '');
    if (g == e) return true;
    final gd = double.tryParse(g);
    final ed = double.tryParse(e);
    if (gd != null && ed != null) return (gd - ed).abs() < 1e-9;
    return false;
  }

  /// 문제의 정답 형태에 맞는 입력 방법 안내
  String _formatHint(MathProblem p) {
    final a = p.answer ?? '';
    if (a.contains('/')) return '분수는 이렇게 써요 → 3/4  (꼭 기약분수로!)';
    if (a.contains(':')) return '비는 이렇게 써요 → 3:5';
    if (a.contains('.')) return '소수는 점(.)을 찍어서 써요 → 1.5';
    return '숫자만 써요 → 12';
  }

  void _onCheck() {
    final p = _mathDay!.problems[_index];
    final given =
        p.kind == 'multipleChoice' ? (_choice ?? '') : _controller.text;
    if (given.trim().isEmpty) return;

    if (_check(given, p.answer ?? '')) {
      _answers[p.id] = given.trim();
      setState(() {
        _correct = true;
        _showWrong = false;
      });
    } else {
      _wrongOnce.add(p.id);
      setState(() => _showWrong = true);
    }
  }

  Future<void> _next() async {
    final problems = _mathDay!.problems;
    if (_index < problems.length - 1) {
      setState(() {
        _index++;
        _correct = false;
        _showWrong = false;
        _controller.clear();
        _choice = null;
      });
      return;
    }

    // 마지막 문제까지 완료 → 서버 제출 (틀렸던 문제 기록 포함)
    setState(() => _submitting = true);
    try {
      await FirestoreService.instance.submitMathDay(
        day: widget.day,
        answers: _answers,
        wrongProblemIds: _wrongOnce.toList(),
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('🎉 오늘의 수학 완료!'),
          content: Text(_wrongOnce.isEmpty
              ? '10문제를 한 번에 전부 맞혔어요! 정말 대단해요!'
              : '10문제를 모두 해결했어요!\n헷갈렸던 문제는 다음에 또 만나요. 힘내요!'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final mathDay = _mathDay;
    if (mathDay == null || mathDay.problems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.day}일차 수학')),
        body: const Center(child: Text('오늘 문제가 아직 등록되지 않았어요.')),
      );
    }

    final problems = mathDay.problems;
    final p = problems[_index];
    final isLast = _index == problems.length - 1;
    final progress = (_index + (_correct ? 1 : 0)) / problems.length;

    return Scaffold(
      appBar: AppBar(title: Text('${mathDay.day}일차 · ${mathDay.unit}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 진행도 ----
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Text('${_index + 1} / ${problems.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),

          // ---- 문제 카드 ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('문제 ${_index + 1}',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AppColors.primary)),
                  const SizedBox(height: 10),
                  Text(p.question,
                      style: const TextStyle(fontSize: 17, height: 1.6)),
                  const SizedBox(height: 16),

                  // ---- 답 입력 ----
                  if (p.kind == 'multipleChoice')
                    ...p.choices.map((c) => RadioListTile<String>(
                          title: Text(c),
                          value: c,
                          groupValue: _choice,
                          onChanged: _correct
                              ? null
                              : (v) => setState(() {
                                    _choice = v;
                                    _showWrong = false;
                                  }),
                        ))
                  else
                    TextField(
                      controller: _controller,
                      enabled: !_correct,
                      onChanged: (_) {
                        if (_showWrong) setState(() => _showWrong = false);
                      },
                      onSubmitted: (_) => _correct ? null : _onCheck(),
                      decoration: InputDecoration(
                        labelText: '답',
                        helperText: '✏️ ${_formatHint(p)}',
                        helperMaxLines: 2,
                      ),
                    ),

                  // ---- 피드백 ----
                  if (_showWrong)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '아직 정답이 아니에요. 다시 한번 생각해 볼까요?\n입력 방법 안내를 확인해 보세요.',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                  if (_correct)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '정답입니다. 잘했어요!',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- 버튼: 정답 확인 → 다음 문제 ----
          SizedBox(
            height: 54,
            child: _correct
                ? FilledButton(
                    onPressed: _submitting ? null : _next,
                    child: Text(_submitting
                        ? '저장 중...'
                        : (isLast ? '완료하기' : '다음 문제')),
                  )
                : FilledButton.tonal(
                    onPressed: _onCheck,
                    child: const Text('정답 확인'),
                  ),
          ),
        ],
      ),
    );
  }
}
