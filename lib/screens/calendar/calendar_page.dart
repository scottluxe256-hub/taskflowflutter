import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:task_flow/main.dart'; 
import '../tasks/widgets/task_item.dart'; 

class CalendarPage extends StatefulWidget {
  final VoidCallback onNavigateToTasks;

  const CalendarPage({super.key, required this.onNavigateToTasks});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String _userName = "User";
  String _avatarUrl = "";
  bool _isLoading = true;

  List<dynamic> _allTasks = []; 
  List<String> _holidays = []; 

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _activeYear = DateTime.now().year;

  RealtimeChannel? _taskChannel;
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchHolidays(_activeYear);

    // KABEL REAL-TIME SPESIFIK CALENDAR (Tugas)
    _taskChannel = Supabase.instance.client
        .channel('calendar_tasks_sync')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'tasks', callback: (payload) => _fetchData())
        .subscribe();
        
    // KABEL REAL-TIME SPESIFIK CALENDAR (Profil)
    _profileChannel = Supabase.instance.client
        .channel('calendar_profiles_sync')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'profiles', callback: (payload) => _fetchData())
        .subscribe();
  }

  @override
  void dispose() {
    if (_taskChannel != null) Supabase.instance.client.removeChannel(_taskChannel!);
    if (_profileChannel != null) Supabase.instance.client.removeChannel(_profileChannel!);
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      try {
        final profile = await Supabase.instance.client.from('profiles').select('*').eq('id', user.id).maybeSingle();
        if (profile != null && mounted) {
           _avatarUrl = profile['avatar_url'] ?? "";
           _userName = profile['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        }
      } catch (_) {}

      final response = await Supabase.instance.client
          .from('tasks')
          .select('*, categories(name, color)')
          .eq('user_id', user.id)
          .eq('is_hidden', false)
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() { _allTasks = response; _isLoading = false; });
        profileNotifier.value = {'name': _userName, 'avatar': _avatarUrl};
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHolidays(int year) async {
    try {
      final response = await http.get(Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/ID'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _holidays = data.map((h) => h['date'].toString()).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal load hari libur: $e");
    }
  }

  Color _getCategoryColor(String? colorStr, String? name) {
    if (colorStr == null || colorStr.isEmpty) return Colors.purpleAccent;
    String hex = colorStr.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
  
  // Fungsi Cepat Ubah Status Tugas dari Calendar
  Future<void> _toggleTaskDone(String id, bool currentStatus) async {
    final newStatus = !currentStatus;
    await Supabase.instance.client.from('tasks').update({'is_completed': newStatus}).eq('id', id);
  }

  List<dynamic> get _tasksForSelectedDate {
    final selectedStr = "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}";
    return _allTasks.where((t) {
      if (t['due_date'] == null) return false;
      return t['due_date'].toString().startsWith(selectedStr);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false, 
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85),
        elevation: 0,
        titleSpacing: 16,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              Text('Mobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
              const Text('Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purpleAccent)),
              const SizedBox(width: 8),
              Text('- v2.4 -', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _fetchData();
                  _fetchHolidays(_activeYear);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
                  child: Row(children: const [Icon(Icons.refresh, size: 14, color: Colors.purpleAccent), SizedBox(width: 4), Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent))]),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.dark_mode : Icons.wb_sunny, color: isDarkMode ? Colors.indigo.shade300 : Colors.amber.shade600),
            onPressed: () => themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: ValueListenableBuilder<Map<String, String>>(
              valueListenable: profileNotifier,
              builder: (context, profile, child) {
                final avatar = profile['avatar'] ?? '';
                final name = profile['name'] ?? 'U';
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty 
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 14)) 
                      : null,
                );
              },
            ),
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isDarkMode ? 'assets/images/bg_mobile_dark.webp' : 'assets/images/bg_mobile.webp'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Jadwal & Agenda", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: widget.onNavigateToTasks,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text("Tugas Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                      if (focusedDay.year != _activeYear) {
                        setState(() => _activeYear = focusedDay.year);
                        _fetchHolidays(focusedDay.year); 
                      }
                    },
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87),
                      leftChevronIcon: Icon(Icons.chevron_left, color: isDarkMode ? Colors.white : Colors.black87),
                      rightChevronIcon: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white : Colors.black87),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black54),
                      weekendStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      defaultTextStyle: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                      selectedDecoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                      selectedTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      todayDecoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.3), shape: BoxShape.circle),
                      todayTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                      weekendTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                        if (_holidays.contains(dateStr)) {
                          return Center(child: Text(day.day.toString(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)));
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Agenda Terjadwal", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text("${_tasksForSelectedDate.length} Agenda", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _isLoading 
                          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)) 
                          : _tasksForSelectedDate.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 32, color: isDarkMode ? Colors.white24 : Colors.black12),
                                    const SizedBox(height: 8),
                                    Text("Tidak ada agenda pada tanggal ini", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
                                  ],
                                ),
                              )
                            : RawScrollbar(
                                thumbColor: Colors.purpleAccent.withOpacity(0.5), radius: const Radius.circular(8), thickness: 4,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _tasksForSelectedDate.length,
                                  itemBuilder: (context, index) {
                                    final task = _tasksForSelectedDate[index];
                                    final catData = task['categories'];
                                    String catName = catData != null ? (catData is List && catData.isNotEmpty ? catData[0]['name'] : (catData is Map ? catData['name'] : "Umum")) ?? "Umum" : "Umum";
                                    String catColorStr = catData != null ? (catData is List && catData.isNotEmpty ? catData[0]['color'] : (catData is Map ? catData['color'] : "")) ?? "" : "";
                                    
                                    return TaskItemCard(
                                      task: task, 
                                      isDarkMode: isDarkMode, 
                                      catName: catName, 
                                      catColor: _getCategoryColor(catColorStr, catName),
                                      onToggle: _toggleTaskDone, 
                                      showActions: false, 
                                    );
                                  },
                                ),
                              ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
