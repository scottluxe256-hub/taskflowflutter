import 'package:flutter/material.dart';

class SweetAlert {
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    required bool isSuccess,
    required bool isDarkMode,
    VoidCallback? onConfirm,
    bool showCancel = false,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250), // Durasi animasi
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.blueGrey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon Gede Ala SweetAlert
                Icon(
                  isSuccess ? Icons.check_circle : Icons.warning_rounded,
                  color: isSuccess ? Colors.green : Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (showCancel) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Batal", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (onConfirm != null) onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSuccess ? Colors.purpleAccent : Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
      // Animasi Zoom-In Ala SweetAlert
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack).value,
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }
}
