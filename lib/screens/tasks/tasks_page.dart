import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_flow/main.dart'; 
import 'widgets/task_item.dart';
import 'widgets/task_modal.dart';
import '../../utils/sweet_alert.dart'; // Sesuaikan lokasi importnya

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String _userName = "User";
  String _avatarUrl = "";
  bool _isLoading = true;

  List<dynamic> _tasks = [];
  List<dynamic> _categories = [];
  
  String _activeCategory = "semua";
  String _activeFilter = "semua";
  String _sortBy = "terbaru";
  String _searchQuery = "";

  RealtimeChannel? _taskChannel;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _taskChannel = Supabase.instance.client
        .channel('public:tasks_view')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'tasks', callback: (payload) => _fetchData())
        .subscribe();
  }

  @override
  void dispose() {
    if (_taskChannel != null) Supabase.instance.client.removeChannel(_taskChannel!);
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

      try {
        final cats = await Supabase.instance.client.from('categories').select('*').eq('user_id', user.id);
        if (mounted) setState(() => _categories = cats);
      } catch (_) {}

      final response = await Supabase.instance.client
          .from('tasks')
          .select('*, categories(name, color)')
          .eq('user_id', user.id)
          .eq('is_hidden', false)
          .order('created_at', ascending: _sortBy == 'terlama');
          
      if (mounted) setState(() { _tasks = response; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getCategoryColor(String? colorStr, String? name) {
    if (colorStr == null || colorStr.isEmpty) return Colors.purpleAccent;
    String hex = colorStr.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  List<dynamic> get _filteredTasks {
    return _tasks.where((task) {
      final catData = task['categories'];
      String catName = catData != null ? (catData is List && catData.isNotEmpty ? catData[0]['name'] : (catData is Map ? catData['name'] : "Umum")) ?? "Umum" : "Umum";
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty || (task['title'] ?? "").toString().toLowerCase().contains(q) || catName.toLowerCase().contains(q);
      final matchCategory = _activeCategory == "semua" || catName.toLowerCase() == _activeCategory.toLowerCase();
      
      bool matchStatus = true;
      final todayStr = DateTime.now().toIso8601String().split("T")[0];
      final taskDateStr = task['due_date'] != null ? task['due_date'].toString().split("T")[0] : "";
      final isCompleted = task['is_completed'] == true;

      if (_activeFilter == "today") matchStatus = task['due_date'] != null && taskDateStr == todayStr;
      else if (_activeFilter == "upcoming") matchStatus = task['due_date'] != null && taskDateStr.compareTo(todayStr) > 0 && !isCompleted;
      else if (_activeFilter == "done") matchStatus = isCompleted;
      else if (_activeFilter == "pending") matchStatus = !isCompleted;

      return matchSearch && matchCategory && matchStatus;
    }).toList();
  }

    Future<void> _toggleTaskDone(String id, bool currentStatus) async {
    final newStatus = !currentStatus;
    setState(() { final idx = _tasks.indexWhere((t) => t['id'] == id); if (idx != -1) _tasks[idx]['is_completed'] = newStatus; });
    await Supabase.instance.client.from('tasks').update({'is_completed': newStatus}).eq('id', id);
    
    // Munculin SweetAlert kalau selesai
    if (newStatus) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      SweetAlert.show(
        context: context, 
        title: "Tugas Selesai! 🎉", 
        message: "Mantap! Lanjutkan semangatmu.", 
        isSuccess: true, 
        isDarkMode: isDarkMode
      );
    }
  }

  Future<void> _deleteTask(String id) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final task = _tasks.firstWhere((t) => t['id'] == id, orElse: () => null);

    // Minta konfirmasi ala SweetAlert sebelum hapus
    SweetAlert.show(
      context: context,
      title: "Hapus Tugas?",
      message: "Tugas ini akan dihapus permanen dan tidak bisa dikembalikan.",
      isSuccess: false,
      isDarkMode: isDarkMode,
      showCancel: true,
      onConfirm: () async {
        setState(() => _tasks.removeWhere((t) => t['id'] == id));
        await Supabase.instance.client.from('tasks').update({'is_hidden': true}).eq('id', id);
        
        // AUTO-DELETE LOGIC: Hapus kategori dari DB kalau udah ga ada tugas lain yang pakai
        if (task != null && task['category_id'] != null) {
          final catId = task['category_id'];
          final countRes = await Supabase.instance.client.from('tasks').select('id').eq('category_id', catId).eq('is_hidden', false);
          if (countRes.isEmpty) {
            await Supabase.instance.client.from('categories').delete().eq('id', catId);
            _fetchData(); 
          }
        }
      }
    );
  }

  void _openTaskModal({Map<String, dynamic>? task}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => TaskModalCenter(taskToEdit: task, categories: _categories, onSuccess: _fetchData),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: const Offset(0, 0)).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // BACKGROUND BERADA DI STACK BAWAH, ANTI BERGERAK SAAT KEYBOARD NAIK
        Positioned.fill(
          child: Image.asset(
            isDarkMode ? 'assets/images/bg_mobile_dark.webp' : 'assets/images/bg_mobile.webp',
            fit: BoxFit.cover,
          ),
        ),
        
        Scaffold(
          backgroundColor: Colors.transparent, // Scaffold wajib tembus pandang
          appBar: AppBar(
            backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85),
            elevation: 0,
            titleSpacing: 16,
            title: Row(
              children: [
                Text('Mobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                const Text('Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purpleAccent)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(isDarkMode ? Icons.dark_mode : Icons.wb_sunny, color: isDarkMode ? Colors.indigo.shade300 : Colors.amber.shade600),
                onPressed: () => themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0, left: 4.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purple.shade100,
                  backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                  child: _avatarUrl.isEmpty ? Text(_userName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 14)) : null,
                ),
              )
            ],
          ),
          body: SafeArea(
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
                            Text("Tugas Saya", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                            const SizedBox(height: 2),
                            Text("Kelola tanggung jawab harianmu.", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openTaskModal,
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDropdown(value: _activeCategory, icon: Icons.local_offer_outlined, items: {'semua': 'Semua Kategori', ...{for (var c in _categories) c['name'].toString().toLowerCase(): c['name']}}, onChanged: (v) { setState(() => _activeCategory = v!); }, isDarkMode: isDarkMode)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDropdown(value: _activeFilter, icon: Icons.filter_alt_outlined, items: {'semua': 'Semua Status', 'today': 'Hari Ini', 'upcoming': 'Mendatang', 'pending': 'Belum Selesai', 'done': 'Selesai'}, onChanged: (v) { setState(() => _activeFilter = v!); }, isDarkMode: isDarkMode)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDropdown(value: _sortBy, icon: Icons.sort, items: {'terbaru': 'Urutkan: Terbaru', 'terlama': 'Urutkan: Terlama'}, onChanged: (v) { setState(() => _sortBy = v!); _fetchData(); }, isDarkMode: isDarkMode),
                        const SizedBox(height: 8),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(color: isDarkMode ? Colors.black26 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300)),
                          child: TextField(
                            textAlignVertical: TextAlignVertical.center, // BIKIN TEKS DI TENGAH
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "Cari tugas atau kategori...",
                              hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45),
                              prefixIcon: Icon(Icons.search, size: 16, color: isDarkMode ? Colors.white54 : Colors.black45),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(bottom: 14), // Penyesuaian vertikal
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200)),
                    child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)) : _filteredTasks.isEmpty ? const Center(child: Text("Kosong ☕")) : RawScrollbar(
                      thumbColor: Colors.purpleAccent.withOpacity(0.5), radius: const Radius.circular(8), thickness: 4,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = _filteredTasks[index];
                          final catData = task['categories'];
                          String catName = catData != null ? (catData is List && catData.isNotEmpty ? catData[0]['name'] : (catData is Map ? catData['name'] : "Umum")) ?? "Umum" : "Umum";
                          String catColorStr = catData != null ? (catData is List && catData.isNotEmpty ? catData[0]['color'] : (catData is Map ? catData['color'] : "")) ?? "" : "";
                          return TaskItemCard(
                            task: task, isDarkMode: isDarkMode, catName: catName, catColor: _getCategoryColor(catColorStr, catName),
                            onToggle: _toggleTaskDone, onEdit: (t) => _openTaskModal(task: t), onDelete: _deleteTask,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({required String value, required IconData icon, required Map<String, String> items, required void Function(String?) onChanged, required bool isDarkMode}) {
    if (!items.containsKey(value)) value = items.keys.first;
    return Container(
      height: 40, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: isDarkMode ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true, icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDarkMode ? Colors.white54 : Colors.black45),
          dropdownColor: isDarkMode ? Colors.blueGrey.shade900 : Colors.white, borderRadius: BorderRadius.circular(16),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Row(children: [Icon(icon, size: 14, color: Colors.purpleAccent), const SizedBox(width: 8), Flexible(child: Text(e.value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)))]))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
