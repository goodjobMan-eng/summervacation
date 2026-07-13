import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

/// 오늘의 기분 데이터: 이모지 + 이름 + 성향(positive/neutral/negative)
class _Mood {
  final String emoji;
  final String label;
  final String valence;
  const _Mood(this.emoji, this.label, this.valence);
}

const _moods = [
  _Mood('🤩', '신나요', 'positive'),
  _Mood('😄', '행복해요', 'positive'),
  _Mood('🙂', '좋아요', 'positive'),
  _Mood('😐', '그냥 그래요', 'neutral'),
  _Mood('😴', '피곤해요', 'neutral'),
  _Mood('😢', '슬퍼요', 'negative'),
  _Mood('😡', '화나요', 'negative'),
  _Mood('😟', '걱정돼요', 'negative'),
];

/// 기분 성향별 이유 선택지
const _reasons = {
  'positive': [
    '친구랑 재미있게 놀아서',
    '칭찬을 받아서',
    '좋아하는 일을 해서',
    '가족과 즐거운 시간을 보내서',
    '맛있는 걸 먹어서',
    '그냥 기분이 좋아서',
  ],
  'neutral': [
    '특별한 일이 없어서',
    '조금 피곤해서',
    '날씨 때문에',
    '잘 모르겠어요',
  ],
  'negative': [
    '친구와 다퉈서',
    '가족에게 혼나서',
    '숙제나 공부가 힘들어서',
    '몸이 아파서',
    '외로워서',
    '걱정되는 일이 있어서',
    '말하고 싶지 않아요',
  ],
};

/// 일일 감정 체크인 — 앱 최초 접속 시 표시되고,
/// 홈 화면에서 언제든 다시 열어 기분을 새로 알릴 수 있다.
/// 결과는 학생 본인과 담당 선생님 대시보드에서만 볼 수 있으며,
/// 힘든 기분이 반복되면 선생님에게 자동으로 알림이 간다.
class EmotionCheckInScreen extends StatefulWidget {
  final String classId;

  /// true면 제출 후 이전 화면으로 돌아간다 (홈에서 다시 열었을 때).
  final bool popOnDone;

  const EmotionCheckInScreen({
    super.key,
    required this.classId,
    this.popOnDone = false,
  });

  @override
  State<EmotionCheckInScreen> createState() => _EmotionCheckInScreenState();
}

class _EmotionCheckInScreenState extends State<EmotionCheckInScreen> {
  _Mood? _selectedMood;
  String? _selectedReason;
  final _commentController = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (_selectedMood == null || _selectedReason == null) return;
    setState(() => _busy = true);
    await FirestoreService.instance.checkInEmotion(
      widget.classId,
      emoji: _selectedMood!.emoji,
      mood: _selectedMood!.valence,
      reason: _selectedReason!,
      comment: _commentController.text.trim(),
    );
    if (!mounted) return;

    final isNegative = _selectedMood!.valence == 'negative';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNegative
            ? '이야기해 줘서 고마워요. 선생님이 함께 살펴봐 줄 거예요 💛'
            : '오늘 기분을 알려줘서 고마워요! 🌞'),
      ),
    );

    if (widget.popOnDone && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _CheckedIn()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons =
        _selectedMood == null ? const <String>[] : _reasons[_selectedMood!.valence]!;

    return Scaffold(
      appBar: widget.popOnDone ? AppBar(title: const Text('오늘 기분')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            const Text('🌈', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text('오늘 기분이 어때요?',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('솔직하게 골라도 괜찮아요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.brown.shade300, height: 1.5)),
            const SizedBox(height: 28),

            // ---- 1단계: 기분 고르기 ----
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _moods.map((m) {
                final selected = _selectedMood == m;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedMood = m;
                    _selectedReason = null; // 기분이 바뀌면 이유도 다시 선택
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 86,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFFE0B2) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFF8A65)
                            : const Color(0xFFFFE4CC),
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 34)),
                        const SizedBox(height: 4),
                        Text(m.label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ---- 2단계: 이유 고르기 (기분 선택 후 나타남) ----
            if (_selectedMood != null) ...[
              const SizedBox(height: 28),
              Text('왜 ${_selectedMood!.label.replaceAll('요', '')} 기분이 들었어요?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: reasons.map((r) {
                  return ChoiceChip(
                    label: Text(r),
                    selected: _selectedReason == r,
                    onSelected: (_) => setState(() => _selectedReason = r),
                  );
                }).toList(),
              ),
            ],

            // ---- 3단계: 하고 싶은 말 (선택) ----
            if (_selectedReason != null) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '더 하고 싶은 말이 있나요? (선택)',
                  hintText: '편하게 적어 보세요.',
                ),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed:
                    _selectedMood == null || _selectedReason == null || _busy
                        ? null
                        : _submit,
                child: Text(_busy ? '보내는 중...' : '마음 보내기 💌'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// 체크인 직후 AuthGate를 다시 타도록 하는 브리지 화면
class _CheckedIn extends StatelessWidget {
  const _CheckedIn();
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
