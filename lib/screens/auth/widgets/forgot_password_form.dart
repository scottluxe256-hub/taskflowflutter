import 'package:flutter/material.dart';
import '../auth_page.dart';

class ForgotPasswordForm extends StatelessWidget {
  final Function(AuthView) onSwitchView;

  const ForgotPasswordForm({super.key, required this.onSwitchView});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Tampilan Lupa Password (Segera Hadir)"),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => onSwitchView(AuthView.login),
          child: const Text("Kembali ke Login"),
        )
      ],
    );
  }
}
