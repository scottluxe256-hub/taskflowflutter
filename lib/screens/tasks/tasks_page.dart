import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_flow/main.dart'; // Panel Listrik Tema

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
  
  // State Filter & Search
  String _activeCategory = "semua";
  String _activeFilter = "semua";
  String _sortBy = "terbaru";
  String _searchQuery = "";

  RealtimeChannel? _taskChannel;

  @override
  void initState() {
    super.initState();
    _fetchData();

    // SISTEM REAL-TIME: Otomatis refresh kalau ada perubahan di database
    _taskChannel = Supabase.instance.client
        .channel('public:tasks_view')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tasks',
            callback: (payload) {
              _fetchData();
            })
        .subscribe();
  }

  @override
  void dispose() {
    if (_taskChannel != null) {
      Supabase.instance.client.removeChannel(_taskChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Ambil Profil
      try {
        final profile = await Supabase.instance.client.from('profiles').select('*').eq('id', user.id).maybeSingle();
        if (profile != null && mounted) {
           _avatarUrl = profile['avatar_url'] ?? "";
           _userName = profile['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        }
      } catch (_) {}

      // Ambil Kategori
      try {
        final cats = await Supabase.instance.client.from('categories').select('*').eq('user_id', user.id);
        if (mounted) setState(() => _categories = cats);
      } catch (_) {}

      // Ambil Tugas (Join dengan categories)
      final response = await Supabase.instance.client
          .from('tasks')
          .select('*, categories(name, color)')
          .eq('user_id', user.id)
          .eq('is_hidden', false)
          .order('created_at', ascending: _sortBy == 'terlama');
          
      if (mounted) {
        setState(() {
          _tasks = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper Warna Kategori (Mirip fungsi di web lu)
  Color _getCategoryColor(String? colorStr, String? name) {
    if (colorStr == null || colorStr.isEmpty) {
      final lowerName = (name ?? "").toLowerCase();
      if (lowerName == "kerja") return Colors.amber;
      if (lowerName == "sekolah") return Colors.blue;
      if (lowerName == "pribadi") return Colors.teal;
      return Colors.purple;
    }
    // Konversi Hex ke Flutter Color
    String hex = colorStr.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  // Logika Filter (Mirip TasksView.tsx)
  List<dynamic> get _filteredTasks {
    return _tasks.where((task) {
      final catData = task['categories'];
      String catName = "Umum";
      if (catData != null) {
        if (catData is List && catData.isNotEmpty) {
          catName = catData[0]['name'] ?? "Umum";
        } else if (catData is Map) {
          catName = catData['name'] ?? "Umum";
        }
      }

      final taskTitle = (task['title'] ?? "").toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      
      final matchSearch = q.isEmpty || taskTitle.contains(q) || catName.toLowerCase().contains(q);
      final matchCategory = _activeCategory == "semua" || catName.toLowerCase() == _activeCategory.toLowerCase();

      bool matchStatus = true;
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final taskDateStr = task['due_date'] != null ? task['due_date'].toString().split("T")[0] : "";
      final isCompleted = task['is_completed'] == true;

      if (_activeFilter == "today") {
        matchStatus = task['due_date'] != null && taskDateStr == todayStr;
      } else if (_activeFilter == "upcoming") {
        matchStatus = task['due_date'] != null && taskDateStr.compareTo(todayStr) > 0 && !isCompleted;
      } else if (_activeFilter == "done") {
        matchStatus = isCompleted;
      } else if (_activeFilter == "pending") {
        matchStatus = !isCompleted;
      }

      return matchSearch && matchCategory && matchStatus;
    }).toList();
  }

  // Aksi Ubah Status
  Future<void> _toggleTaskDone(String id, bool currentStatus) async {
    final newStatus = !currentStatus;
    // Optimistic Update
    setState(() {
      final index = _tasks.indexWhere((t) => t['id'] == id);
      if (index != -1) _tasks[index]['is_completed'] = newStatus;
    });
    
    await Supabase.instance.client.from('tasks').update({'is_completed': newStatus}).eq('id', id);
    if (newStatus) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas Selesai! 🎉', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
    }
  }

  // Aksi Hapus (Soft Delete)
  Future<void> _deleteTask(String id) async {
    setState(() {
      _tasks.removeWhere((t) => t['id'] == id);
    });
    await Supabase.instance.client.from('tasks').update({'is_hidden': true}).eq('id', id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas berhasil dihapus', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
  }

  // BUKA MODAL BOTTOM SHEET TAMBAH/EDIT
  void _openTaskModal({Map<String, dynamic>? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Biar bisa naik full sampai atas keyboard
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskModalSheet(
        taskToEdit: task,
        categories: _categories,
        onSuccess: _fetchData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Text('Mobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
            const Text('Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purple)),
            const SizedBox(width: 8),
            Text('- v2.4 -', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _fetchData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purple.withOpacity(0.3))),
                child: Row(
                  children: const [
                    Icon(Icons.refresh, size: 14, color: Colors.purple),
                    SizedBox(width: 4),
                    Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                  ],
                ),
              ),
            ),
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
              child: _avatarUrl.isEmpty ? Text(_userName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 14)) : null,
            ),
          )
        ],
      ),
      // Container Full Screen Anti Bocor
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
          // PENGGUNAAN COLUMN AGAR BISA MEMAKAI EXPANDED (Tinggi Maksimal & Scroll Terpisah)
          child: Column(
            children: [
              // HEADER (Tugas Saya & Tombol Tambah di Kanan)
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
                          Text("Kelola dan selesaikan tanggung jawab harianmu.", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openTaskModal,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text("Tugas Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 5,
                        shadowColor: Colors.purple.withOpacity(0.5)
                      ),
                    )
                  ],
                ),
              ),

              // FILTER BAR (3 Baris Persis UI Web Mobile)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Column(
                    children: [
                      // Baris 1: Kategori & Status (Sejajar)
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              value: _activeCategory,
                              icon: Icons.local_offer_outlined,
                              items: {'semua': 'Semua Kategori', 'kerja': 'Kerja', 'sekolah': 'Sekolah', 'pribadi': 'Pribadi'},
                              onChanged: (v) { setState(() => _activeCategory = v!); _fetchData(); },
                              isDarkMode: isDarkMode
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDropdown(
                              value: _activeFilter,
                              icon: Icons.filter_alt_outlined,
                              items: {'semua': 'Semua Status', 'today': 'Hari Ini', 'upcoming': 'Mendatang', 'pending': 'Belum Selesai', 'done': 'Selesai'},
                              onChanged: (v) { setState(() => _activeFilter = v!); },
                              isDarkMode: isDarkMode
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Baris 2: Urutkan Full Width
                      _buildDropdown(
                        value: _sortBy,
                        icon: Icons.sort,
                        items: {'terbaru': 'Urutkan: Terbaru', 'terlama': 'Urutkan: Terlama'},
                        onChanged: (v) { setState(() => _sortBy = v!); _fetchData(); },
                        isDarkMode: isDarkMode
                      ),
                      const SizedBox(height: 8),
                      // Baris 3: Search Bar
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300)
                        ),
                        child: TextField(
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: "Cari tugas atau kategori...",
                            hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45),
                            prefixIcon: Icon(Icons.search, size: 16, color: isDarkMode ? Colors.white54 : Colors.black45),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(top: -4), // Center vertically
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // DAFTAR TUGAS (Tinggi memanjang ke bawah berkat Expanded, anti bocor navbar)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24), // Bottom 24 = jarak aman navbar
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                    : _filteredTasks.isEmpty
                      ? Center(child: Text("Tidak ada tugas yang sesuai ☕", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold)))
                      : RawScrollbar(
                          thumbColor: Colors.purple.withOpacity(0.5),
                          radius: const Radius.circular(8),
                          thickness: 4,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = _filteredTasks[index];
                              
                              // Parse Categori Name & Color
                              final catData = task['categories'];
                              String catName = "Umum";
                              String catColorStr = "";
                              if (catData != null) {
                                if (catData is List && catData.isNotEmpty) {
                                  catName = catData[0]['name'] ?? "Umum";
                                  catColorStr = catData[0]['color'] ?? "";
                                } else if (catData is Map) {
                                  catName = catData['name'] ?? "Umum";
                                  catColorStr = catData['color'] ?? "";
                                }
                              }
                              final Color catColor = _getCategoryColor(catColorStr, catName);

                              // Parse Tanggal & Waktu
                              String timeStr = "09:00";
                              String dateStr = "Hari Ini";
                              if (task['due_date'] != null) {
                                final d = DateTime.parse(task['due_date']).toLocal();
                                timeStr = "${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}";
                                dateStr = "${d.day} ${_getMonthName(d.month)}";
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.blueGrey.shade800 : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200)
                                ),
                                child: Row(
                                  children: [
                                    // Tombol Selesai
                                    GestureDetector(
                                      onTap: () => _toggleTaskDone(task['id'], task['is_completed'] == true),
                                      child: Icon(task['is_completed'] == true ? Icons.check_circle : Icons.circle_outlined, color: task['is_completed'] == true ? Colors.green : Colors.grey, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    // Info Tugas
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task['title'] ?? 'Tanpa Judul',
                                            style: TextStyle(
                                              fontSize: 14, 
                                              fontWeight: FontWeight.bold, 
                                              decoration: task['is_completed'] == true ? TextDecoration.lineThrough : null, 
                                              color: task['is_completed'] == true ? (isDarkMode ? Colors.white38 : Colors.black38) : (isDarkMode ? Colors.white : Colors.black87)
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.schedule, size: 12, color: isDarkMode ? Colors.white54 : Colors.black45),
                                              const SizedBox(width: 4),
                                              Text("$timeStr • $dateStr", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black45)),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    // Badge Kategori
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: catColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: catColor.withOpacity(0.3))),
                                      child: Text(catName.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: catColor)),
                                    ),
                                    const SizedBox(width: 8),
                                    // Icon Edit & Hapus
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _openTaskModal(task: task),
                                          child: Icon(Icons.edit_outlined, size: 16, color: isDarkMode ? Colors.white54 : Colors.black45),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _deleteTask(task['id']),
                                          child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
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
    );
  }

  // Widget Helper buat bikin Dropdown cantik
  Widget _buildDropdown({required String value, required IconData icon, required Map<String, String> items, required void Function(String?) onChanged, required bool isDarkMode}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDarkMode ? Colors.white54 : Colors.black45),
          isExpanded: true,
          dropdownColor: isDarkMode ? Colors.blueGrey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: items.entries.map((e) {
            return DropdownMenuItem(
              value: e.key,
              child: Row(
                children: [
                  Icon(icon, size: 14, color: Colors.purple),
                  const SizedBox(width: 8),
                  Flexible(child: Text(e.value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87))),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Ags", "Sep", "Okt", "Nov", "Des"];
    return months[month - 1];
  }
}

// ==========================================
// BOTTOM SHEET UNTUK FORM TAMBAH/EDIT TUGAS
// ==========================================
class _TaskModalSheet extends StatefulWidget {
  final Map<String, dynamic>? taskToEdit;
  final List<dynamic> categories;
  final VoidCallback onSuccess;

  const _TaskModalSheet({this.taskToEdit, required this.categories, required this.onSuccess});

  @override
  State<_TaskModalSheet> createState() => _TaskModalSheetState();
}

class _TaskModalSheetState extends State<_TaskModalSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories[0]['id'].toString();
    }
    
    // Kalau mode Edit, isi data formnya
    if (widget.taskToEdit != null) {
      _titleController.text = widget.taskToEdit!['title'] ?? '';
      _descController.text = widget.taskToEdit!['description'] ?? '';
      _selectedCategory = widget.taskToEdit!['category_id']?.toString() ?? _selectedCategory;
      
      if (widget.taskToEdit!['due_date'] != null) {
        final d = DateTime.parse(widget.taskToEdit!['due_date']).toLocal();
        _selectedDate = d;
        _selectedTime = TimeOfDay.fromDateTime(d);
      }
    }
  }

  Future<void> _saveData() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final dueObj = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
      
      final payload = {
        'user_id': user!.id,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category_id': _selectedCategory,
        'due_date': dueObj.toIso8601String(),
      };

      if (widget.taskToEdit == null) {
        await Supabase.instance.client.from('tasks').insert(payload); // Create
      } else {
        await Supabase.instance.client.from('tasks').update(payload).eq('id', widget.taskToEdit!['id']); // Update
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Gagal simpan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      // Padding bottom supaya inputan terdorong naik saat keyboard HP muncul
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F172A) : Colors.white, // Solid color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300)
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Biar tinggi pop-up menyesuaikan isi form
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Text(widget.taskToEdit == null ? "Tambah Tugas Baru" : "Edit Detail Tugas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          
          // Form Judul
          TextField(
            controller: _titleController,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Judul Tugas *",
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
              filled: true,
              fillColor: isDarkMode ? Colors.black26 : Colors.purple.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          
          // Kategori & Tanggal/Waktu
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: isDarkMode ? Colors.black26 : Colors.purple.shade50, borderRadius: BorderRadius.circular(16)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      dropdownColor: isDarkMode ? Colors.blueGrey.shade900 : Colors.white,
                      items: widget.categories.map((c) => DropdownMenuItem(
                        value: c['id'].toString(), 
                        child: Text(c['name'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87))
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (date != null) {
                      final time = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (time != null) setState(() { _selectedDate = date; _selectedTime = time; });
                    }
                  },
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: isDarkMode ? Colors.black26 : Colors.purple.shade50, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 16, color: Colors.purple),
                        const SizedBox(width: 8),
                        Text("${_selectedDate.day}/${_selectedDate.month} - ${_selectedTime.format(context)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          
          // Form Catatan
          TextField(
            controller: _descController,
            maxLines: 3,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Catatan Tambahan (Opsional)",
              labelStyle: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54),
              filled: true,
              fillColor: isDarkMode ? Colors.black26 : Colors.purple.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          
          // Tombol Aksi
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.blueGrey.shade800 : Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text("Batal", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Simpan Data", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
