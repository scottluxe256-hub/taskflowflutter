import 'package:flutter/material.dart';
import '../auth_page.dart';

class ResetPasswordForm extends StatelessWidget {
  final Function(AuthView) onSwitchView;

  const ResetPasswordForm({super.key, required this.onSwitchView});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Tampilan Reset Password (Segera Hadir)"),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => onSwitchView(AuthView.login),
          child: const Text("Kembali ke Login"),
        )
      ],
    );
  }
}
