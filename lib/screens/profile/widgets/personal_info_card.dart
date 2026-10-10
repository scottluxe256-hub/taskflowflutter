import 'package:flutter/material.dart';

class PersonalInfoCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isDarkMode;
  final Function(String name, String username, String bio) onSave;
  final bool isSaving;

  const PersonalInfoCard({super.key, required this.user, required this.isDarkMode, required this.onSave, required this.isSaving});

  @override
  State<PersonalInfoCard> createState() => _PersonalInfoCardState();
}

class _PersonalInfoCardState extends State<PersonalInfoCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['name'] ?? '');
    _usernameCtrl = TextEditingController(text: widget.user['username'] ?? '');
    _bioCtrl = TextEditingController(text: widget.user['bio'] ?? '');
  }

  // <-- LOGIKA DETEKSI PERUBAHAN LEBIH PEKA AGAR REAL-TIME JALAN -->
  @override
  void didUpdateWidget(covariant PersonalInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSaving) {
      if (oldWidget.user['name'] != widget.user['name']) {
        _nameCtrl.text = widget.user['name'] ?? '';
      }
      if (oldWidget.user['username'] != widget.user['username']) {
        _usernameCtrl.text = widget.user['username'] ?? '';
      }
      if (oldWidget.user['bio'] != widget.user['bio']) {
        _bioCtrl.text = widget.user['bio'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final boxStyle = BoxDecoration(color: isDark ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]);
    final inputDecor = InputDecoration(filled: true, fillColor: isDark ? Colors.black45 : Colors.white70, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
    final labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87);

    return Container(
      padding: const EdgeInsets.all(20), decoration: boxStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Informasi Pribadi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
          
          Text("Nama Lengkap", style: labelStyle),
          const SizedBox(height: 6),
          TextField(controller: _nameCtrl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), decoration: inputDecor.copyWith(prefixIcon: const Icon(Icons.person, size: 16))),
          const SizedBox(height: 12),
          
          Text("Username", style: labelStyle),
          const SizedBox(height: 6),
          TextField(controller: _usernameCtrl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), decoration: inputDecor.copyWith(prefixIcon: const Icon(Icons.alternate_email, size: 16))),
          const SizedBox(height: 12),
          
          Text("Email (Read-Only)", style: labelStyle),
          const SizedBox(height: 6),
          TextField(controller: TextEditingController(text: widget.user['email']), enabled: false, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54), decoration: inputDecor.copyWith(prefixIcon: const Icon(Icons.mail, size: 16))),
          const SizedBox(height: 12),
          
          Text("Bio Singkat", style: labelStyle),
          const SizedBox(height: 6),
          TextField(controller: _bioCtrl, maxLines: 2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), decoration: inputDecor),
          const SizedBox(height: 16),
          
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: widget.isSaving ? null : () => widget.onSave(_nameCtrl.text, _usernameCtrl.text, _bioCtrl.text),
              icon: widget.isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, size: 16, color: Colors.white),
              label: Text(widget.isSaving ? "Menyimpan..." : "Simpan Perubahan", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          )
        ],
      ),
    );
  }
}
