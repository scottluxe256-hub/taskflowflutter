import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveSessionsCard extends StatefulWidget {
  final bool isDarkMode;
  const ActiveSessionsCard({super.key, required this.isDarkMode});

  @override
  State<ActiveSessionsCard> createState() => _ActiveSessionsCardState();
}

class _ActiveSessionsCardState extends State<ActiveSessionsCard> {
  bool _reminderEnabled = false;
  String _reminderDuration = "15 Menit";
  bool _autoDelete = false;

  @override
  void initState() {
    super.initState();
    _fetchPreferences();
  }

  Future<void> _fetchPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res = await Supabase.instance.client.from('profiles').select('reminder_enabled, reminder_duration, auto_delete_tasks').eq('id', user.id).maybeSingle();
    if (res != null && mounted) {
      setState(() {
        _reminderEnabled = res['reminder_enabled'] ?? false;
        _reminderDuration = res['reminder_duration'] ?? "15 Menit";
        _autoDelete = res['auto_delete_tasks'] ?? false;
      });
    }
  }

  Future<void> _updatePref(String key, dynamic value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('profiles').update({key: value}).eq('id', user.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Aturan Tugas Default", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
          
          _buildToggleItem("Aktifkan Tenggat Waktu", "Setel pengingat default otomatis.", _reminderEnabled, (val) {
            setState(() => _reminderEnabled = val);
            _updatePref('reminder_enabled', val);
          }),
          const SizedBox(height: 16),
          _buildToggleItem("Hapus Tugas Otomatis", "Tugas terhapus saat ditandai selesai.", _autoDelete, (val) {
            setState(() => _autoDelete = val);
            _updatePref('auto_delete_tasks', val);
          }),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, String subtitle, bool value, Function(bool) onChanged) {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          ),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeColor: Colors.purpleAccent,
            activeTrackColor: Colors.purpleAccent.withOpacity(0.3),
            inactiveThumbColor: isDark ? Colors.grey.shade400 : Colors.grey.shade300,
            inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          )
        ],
      ),
    );
  }
}
