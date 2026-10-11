import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskModalCenter extends StatefulWidget {
  final Map<String, dynamic>? taskToEdit;
  final List<dynamic> categories;
  final VoidCallback onSuccess;

  const TaskModalCenter({super.key, this.taskToEdit, required this.categories, required this.onSuccess});

  @override
  State<TaskModalCenter> createState() => _TaskModalCenterState();
}

class _TaskModalCenterState extends State<TaskModalCenter> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _customCatController = TextEditingController();
  final _hexColorController = TextEditingController(); // Controller untuk warna bebas
  
  String? _selectedCategory;
  bool _isCreatingCustomCat = false;
  Color _selectedCustomColor = Colors.purpleAccent;
  String? _errorMsg; // Pesan error seperti di React

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;

  final List<Color> _presetColors = [Colors.purpleAccent, Colors.pinkAccent, Colors.cyan, Colors.amber];

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories[0]['id'].toString();
    }
    
    // Inisialisasi controller HEX warna awal
    _hexColorController.text = '#${_selectedCustomColor.value.toRadixString(16).substring(2, 8).padLeft(6, '0').toUpperCase()}';
    
    if (widget.taskToEdit != null) {
      _titleController.text = widget.taskToEdit!['title'] ?? '';
      _descController.text = widget.taskToEdit!['description'] ?? '';
      
      final editCatId = widget.taskToEdit!['category_id']?.toString();
      if (editCatId != null && widget.categories.any((c) => c['id'].toString() == editCatId)) {
        _selectedCategory = editCatId;
      }
      
      if (widget.taskToEdit!['due_date'] != null) {
        final d = DateTime.parse(widget.taskToEdit!['due_date']).toLocal();
        _selectedDate = d;
        _selectedTime = TimeOfDay.fromDateTime(d);
      }
    }
  }

  // Fungsi membaca input HEX secara Real-Time
  void _updateCustomColorFromHex(String hex) {
    if (hex.length == 7 && hex.startsWith('#')) {
      try {
        final color = Color(int.parse(hex.substring(1, 7), radix: 16) + 0xFF000000);
        setState(() => _selectedCustomColor = color);
      } catch (_) {} // Abaikan jika format salah
    }
  }

  Future<void> _saveData() async {
    setState(() => _errorMsg = null);
    
    if (_titleController.text.trim().isEmpty) {
      setState(() => _errorMsg = "Judul tugas tidak boleh kosong.");
      return;
    }
    if (_selectedCategory == null && !_isCreatingCustomCat) {
      setState(() => _errorMsg = "Silakan pilih kategori tugas terlebih dahulu!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Pengguna belum terautentikasi.");

      String? finalCategoryId = _selectedCategory;

      if (_isCreatingCustomCat && _customCatController.text.trim().isNotEmpty) {
        final newCatName = _customCatController.text.trim();
        final existingIdx = widget.categories.indexWhere((c) => (c['name'] ?? "").toString().toLowerCase() == newCatName.toLowerCase());

        if (existingIdx != -1) {
          finalCategoryId = widget.categories[existingIdx]['id'].toString();
        } else {
          final hexColor = '#${_selectedCustomColor.value.toRadixString(16).substring(2, 8).padLeft(6, '0')}';
          final catResponse = await Supabase.instance.client.from('categories').insert({
            'user_id': user.id,
            'name': newCatName,
            'color': hexColor,
          }).select().single();
          finalCategoryId = catResponse['id'].toString();
        }
      }

      final dueObj = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute).toUtc();
      
      final payload = {
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'category_id': finalCategoryId,
        'due_date': dueObj.toIso8601String(),
        if (widget.taskToEdit == null) 'is_completed': false,
      };

      if (widget.taskToEdit == null) {
        await Supabase.instance.client.from('tasks').insert(payload);
      } else {
        await Supabase.instance.client.from('tasks').update(payload).eq('id', widget.taskToEdit!['id']);
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMsg = "Gagal menyimpan tugas.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    bool isValidCat = widget.categories.any((c) => c['id'].toString() == _selectedCategory);
    if (!isValidCat && widget.categories.isNotEmpty) _selectedCategory = widget.categories[0]['id'].toString();

    // Palet warna agar 100% match dengan React
    final labelColor = isDarkMode ? Colors.white : Colors.black;
    final inputBgColor = isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final borderColor = isDarkMode ? Colors.white12 : Colors.grey.shade300;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF070D1E).withOpacity(0.85) : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, spreadRadius: -5)],
                image: DecorationImage(
                  image: AssetImage(isDarkMode ? 'assets/images/bg_card_dark.webp' : 'assets/images/bg_card.webp'), 
                  fit: BoxFit.cover, 
                  alignment: Alignment.topCenter,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(isDarkMode ? 0.4 : 0.05), BlendMode.dstATop),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // HEADER LOGO & TITLE
                    Center(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1), blurRadius: 15, spreadRadius: 1)]),
                            child: Image.asset('assets/images/logo.webp', width: 44, height: 44),
                          ),
                          const SizedBox(height: 10),
                          Text(widget.taskToEdit == null ? "Tambah Tugas Baru" : "Edit Detail Tugas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: labelColor, letterSpacing: -0.5), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // ERROR MESSAGE BOX (Fitur baru seperti React)
                    if (_errorMsg != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), border: Border.all(color: Colors.red.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
                        child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    
                    // 1. JUDUL TUGAS
                    Text("Judul Tugas *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: labelColor)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      autofocus: widget.taskToEdit == null,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: labelColor),
                      decoration: InputDecoration(
                        hintText: "Mau menyelesaikan apa hari ini?",
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black38, fontWeight: FontWeight.w600),
                        filled: true, 
                        fillColor: inputBgColor, 
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.purpleAccent, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    
                    // 2. KATEGORI (Dropdown Sleek / Input Kustom Bebas)
                    if (!_isCreatingCustomCat) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder_outlined, size: 18, color: Colors.purpleAccent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedCategory,
                                        isExpanded: true,
                                        icon: Icon(Icons.keyboard_arrow_down, color: isDarkMode ? Colors.white54 : Colors.black54),
                                        dropdownColor: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                                        hint: Text("Pilih Kategori", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                                        items: widget.categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)))).toList(),
                                        onChanged: (v) => setState(() => _selectedCategory = v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => setState(() => _isCreatingCustomCat = true),
                            child: Container(
                              height: 52, width: 52,
                              decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
                              child: const Icon(Icons.add, color: Colors.purpleAccent),
                            ),
                          )
                        ],
                      )
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Kategori Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.purpleAccent)),
                                GestureDetector(onTap: () => setState(() => _isCreatingCustomCat = false), child: const Text("Batal", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)))
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _customCatController, 
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: labelColor), 
                              decoration: InputDecoration(hintText: "Nama Kategori...", hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black38), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), border: InputBorder.none)
                            ),
                            const Divider(height: 20, color: Colors.white12),
                            
                            // WARNA BEBAS + PRESET (Ini perbaikannya!)
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(color: isDarkMode ? Colors.black26 : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                                    child: Row(
                                      children: [
                                        Container(width: 16, height: 16, decoration: BoxDecoration(color: _selectedCustomColor, shape: BoxShape.circle, border: Border.all(color: Colors.white38))),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _hexColorController,
                                            onChanged: _updateCustomColorFromHex,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor),
                                            decoration: const InputDecoration(hintText: "#HEX", border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                          ),
                                        )
                                      ],
                                    )
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                    children: _presetColors.map((color) => GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCustomColor = color;
                                          _hexColorController.text = '#${color.value.toRadixString(16).substring(2, 8).padLeft(6, '0').toUpperCase()}';
                                        });
                                      }, 
                                      child: CircleAvatar(backgroundColor: color, radius: 12, child: _selectedCustomColor == color ? const Icon(Icons.check, size: 14, color: Colors.white) : null)
                                    )).toList()
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      )
                    ],

                    const SizedBox(height: 14),
                    
                    // 3. TANGGAL & WAKTU (Mirip Grid React)
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 14, color: Colors.purpleAccent),
                        const SizedBox(width: 6),
                        Text("Tanggal & Waktu", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: labelColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (date != null) setState(() => _selectedDate = date);
                            },
                            child: Container(
                              height: 48, padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                              child: Align(alignment: Alignment.centerLeft, child: Text("${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: labelColor)))
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(context: context, initialTime: _selectedTime);
                              if (time != null) setState(() => _selectedTime = time);
                            },
                            child: Container(
                              height: 48, padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                              child: Align(alignment: Alignment.centerLeft, child: Text("${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: labelColor)))
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // 4. CATATAN TAMBAHAN
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 14, color: Colors.purpleAccent),
                        const SizedBox(width: 6),
                        Text("Catatan Tambahan (Opsional)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: labelColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descController, maxLines: 3,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                      decoration: InputDecoration(
                        hintText: "Tambahkan rincian atau catatan tugas di sini...", 
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black38), 
                        filled: true, 
                        fillColor: inputBgColor, 
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.purpleAccent, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 5. TOMBOL AKSI
                    Row(
                      children: [
                        Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: isDarkMode ? Colors.blueGrey.shade800 : Colors.grey.shade200, foregroundColor: labelColor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Batal", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _saveData, style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, elevation: 4, shadowColor: Colors.purpleAccent.withOpacity(0.5), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text("Simpan Data", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
