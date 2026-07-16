import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/firestore_service.dart';
import '../../theme.dart';

const kRegions = [
  '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
  '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
];

/// 교사용 학급 개설 화면
/// 지역 → 학교/학급/이름 → 방학 시작일을 입력하면
/// 서버가 참여 코드(6자리)와 비밀번호(4자리)를 발급한다.
class TeacherCreateClassScreen extends StatefulWidget {
  const TeacherCreateClassScreen({super.key});

  @override
  State<TeacherCreateClassScreen> createState() =>
      _TeacherCreateClassScreenState();
}

class _TeacherCreateClassScreenState extends State<TeacherCreateClassScreen> {
  String? _region;
  final _school = TextEditingController();
  final _className = TextEditingController(text: '6학년 ');
  final _teacherName = TextEditingController();
  DateTime _startDate = DateTime.now();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result; // {joinCode, password}

  Future<void> _create() async {
    if (_region == null ||
        _school.text.trim().isEmpty ||
        _className.text.trim().isEmpty ||
        _teacherName.text.trim().isEmpty) {
      setState(() => _error = '모든 항목을 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final result = await FirestoreService.instance.createClass(
        region: _region!,
        school: _school.text.trim(),
        className: _className.text.trim(),
        teacherName: _teacherName.text.trim(),
        missionStartDate: FirestoreService.instance.dateKey(_startDate),
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = '개설에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 개설 완료 → 코드/비밀번호 안내 화면
    if (_result != null) return _buildResult(context);

    return Scaffold(
      appBar: AppBar(title: const Text('학급 개설')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('지역', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: kRegions
                .map((r) => ChoiceChip(
                      label: Text(r),
                      selected: _region == r,
                      onSelected: (_) => setState(() => _region = r),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _school,
            decoration: const InputDecoration(
                labelText: '학교 이름', hintText: '예: ○○초등학교'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _className,
            decoration: const InputDecoration(
                labelText: '학급 이름', hintText: '예: 6학년 1반'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teacherName,
            decoration: const InputDecoration(
                labelText: '선생님 이름', hintText: '예: 김하늘'),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: const Text('방학 미션 시작일'),
              subtitle:
                  Text(FirestoreService.instance.dateKey(_startDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 60)),
                  lastDate: DateTime.now().add(const Duration(days: 120)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(_busy ? '개설 중...' : '학급 개설하고 코드 받기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final code = _result!['joinCode'];
    final password = _result!['password'];
    return Scaffold(
      appBar: AppBar(title: const Text('학급 개설 완료'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.verified_outlined, size: 52, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text(
            '학급이 개설되었습니다.\n아래 코드와 비밀번호를 학생들에게 안내해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 24),
          _CodeCard(label: '참여 코드', value: code),
          const SizedBox(height: 10),
          _CodeCard(label: '비밀번호', value: password),
          const SizedBox(height: 12),
          const Text(
            '※ 코드와 비밀번호는 대시보드에서 언제든 다시 확인할 수 있어요.\n'
            '※ 학급을 개설한 담임 선생님만 우리 반 학생 데이터를 볼 수 있습니다.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.6),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              // AuthGate가 역할을 다시 읽어 교사 대시보드로 이동
              onPressed: () => Navigator.of(context)
                  .popUntil((route) => route.isFirst),
              child: const Text('대시보드로 가기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String label;
  final String value;
  const _CodeCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 4)),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: '복사',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label을(를) 복사했어요.')));
          },
        ),
      ),
    );
  }
}
