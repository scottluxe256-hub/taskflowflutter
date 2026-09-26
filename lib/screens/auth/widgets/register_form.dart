import 'package:flutter/material.dart';
import '../auth_page.dart';

class RegisterForm extends StatelessWidget {
  final Function(AuthView) onSwitchView;

  const RegisterForm({super.key, required this.onSwitchView});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Tampilan Register (Segera Hadir)"),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => onSwitchView(AuthView.login),
          child: const Text("Kembali ke Login"),
        )
      ],
    );
  }
}
