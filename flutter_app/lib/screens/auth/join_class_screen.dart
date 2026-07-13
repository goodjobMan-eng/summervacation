import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

/// 학생용 학급 입장 화면
/// 선생님께 받은 참여 코드 + 비밀번호를 입력하면
/// joinClass callable이 검증 후 자기 반(classes/{classId}/students/{uid})에 등록한다.
class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _join() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || code.isEmpty || password.isEmpty) {
      setState(() => _error = '이름, 참여 코드, 비밀번호를 모두 입력해 주세요.');
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
      await FirestoreService.instance.joinClassWithCode(code, password, name);
      // AuthGate의 watchMe() 스트림이 갱신되면서 자동으로 홈 화면 이동
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() =>
          _error = '들어가지 못했어요. 코드와 비밀번호를 선생님께 다시 확인해 보세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('우리 반 들어가기 🎒')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                const Text('🏫', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text('선생님께 받은 코드와 비밀번호로 시작해요!',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 28),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '학급 참여 코드',
                    hintText: '예: MJ6A2K',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 (숫자 4자리)',
                    hintText: '예: 1234',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _join,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('우리 반 들어가기'),
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
