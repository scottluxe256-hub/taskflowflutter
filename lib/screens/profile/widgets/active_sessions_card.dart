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

  final List<String> _durationOpts = ["15 Menit", "1 Jam", "1 Hari", "Custom"];
  final List<String> _unitOpts = ["Menit", "Jam", "Hari"];
  
  String _customValue = "30";
  String _customUnit = "Menit";
  bool _isCustomConfirmed = false;

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
        String dur = res['reminder_duration'] ?? "15 Menit";
        if (!_durationOpts.contains(dur) && dur.isNotEmpty) {
          _reminderDuration = "Custom";
          _isCustomConfirmed = true;
          final parts = dur.split(' ');
          if (parts.length == 2) { _customValue = parts[0]; _customUnit = parts[1]; }
        } else {
          _reminderDuration = dur;
        }
        _autoDelete = res['auto_delete_tasks'] ?? false;
      });
    }
  }

  Future<void> _updatePref(String key, dynamic value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('profiles').update({key: value}).eq('id', user.id);
  }

  void _handleSelectDuration(String? val) {
    if (val == null) return;
    setState(() {
      _reminderDuration = val;
      if (val != "Custom") {
        _isCustomConfirmed = false;
        _updatePref('reminder_duration', val);
      } else {
        _isCustomConfirmed = false;
      }
    });
  }

  void _handleConfirmCustom() {
    if (_customValue.trim().isEmpty) return;
    final customStr = "$_customValue $_customUnit";
    setState(() => _isCustomConfirmed = true);
    _updatePref('reminder_duration', customStr);
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
          
          // TENGGAT WAKTU ROW
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Aktifkan Tenggat Waktu", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text("Setel pengingat default otomatis.", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (_reminderEnabled) ...[
                      Container(
                        height: 32, padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _reminderDuration,
                            icon: const Icon(Icons.arrow_drop_down, size: 16),
                            dropdownColor: isDark ? Colors.blueGrey.shade900 : Colors.white,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                            items: _durationOpts.map((String val) {
                              String label = val;
                              if (val == "Custom" && _isCustomConfirmed) label = "$_customValue $_customUnit";
                              return DropdownMenuItem(value: val, child: Text(label));
                            }).toList(),
                            onChanged: _handleSelectDuration,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Switch(
                      value: _reminderEnabled, 
                      onChanged: (val) {
                        setState(() => _reminderEnabled = val);
                        _updatePref('reminder_enabled', val);
                      },
                      activeColor: Colors.purpleAccent, activeTrackColor: Colors.purpleAccent.withOpacity(0.3),
                      inactiveThumbColor: isDark ? Colors.grey.shade400 : Colors.grey.shade300, inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ],
                )
              ],
            ),
          ),

          // TAMPILAN CUSTOM INPUT
          if (_reminderEnabled && _reminderDuration == "Custom" && !_isCustomConfirmed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 60, height: 32,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(filled: true, fillColor: isDark ? Colors.black26 : Colors.white, contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300))),
                      onChanged: (v) => _customValue = v,
                      controller: TextEditingController(text: _customValue)..selection = TextSelection.fromPosition(TextPosition(offset: _customValue.length)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 32, padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _customUnit,
                        icon: const Icon(Icons.arrow_drop_down, size: 16),
                        dropdownColor: isDark ? Colors.blueGrey.shade900 : Colors.white,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        items: _unitOpts.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setState(() => _customUnit = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.purpleAccent, size: 24),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    onPressed: _handleConfirmCustom,
                  )
                ],
              ),
            ),

          const SizedBox(height: 16),
          // AUTO DELETE ROW
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hapus Tugas Otomatis", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text("Tugas terhapus saat ditandai selesai.", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
                    ],
                  ),
                ),
                Switch(
                  value: _autoDelete, 
                  onChanged: (val) {
                    setState(() => _autoDelete = val);
                    _updatePref('auto_delete_tasks', val);
                  },
                  activeColor: Colors.purpleAccent, activeTrackColor: Colors.purpleAccent.withOpacity(0.3),
                  inactiveThumbColor: isDark ? Colors.grey.shade400 : Colors.grey.shade300, inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
