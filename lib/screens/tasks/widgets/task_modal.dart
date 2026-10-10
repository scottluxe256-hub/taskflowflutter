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
  
  String? _selectedCategory;
  bool _isCreatingCustomCat = false;
  Color _selectedCustomColor = Colors.purpleAccent;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;

  final List<Color> _presetColors = [Colors.purpleAccent, Colors.pinkAccent, Colors.cyan, Colors.amber, Colors.greenAccent];

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories[0]['id'].toString();
    }
    
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

  Future<void> _saveData() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      String? finalCategoryId = _selectedCategory;

      if (_isCreatingCustomCat && _customCatController.text.trim().isNotEmpty) {
        final newCatName = _customCatController.text.trim();
        final existingIdx = widget.categories.indexWhere((c) => (c['name'] ?? "").toString().toLowerCase() == newCatName.toLowerCase());

        if (existingIdx != -1) {
          finalCategoryId = widget.categories[existingIdx]['id'].toString();
        } else {
          final hexColor = '#${_selectedCustomColor.value.toRadixString(16).substring(2).padLeft(6, '0')}';
          final catResponse = await Supabase.instance.client.from('categories').insert({
            'user_id': user!.id,
            'name': newCatName,
            'color': hexColor,
          }).select().single();
          finalCategoryId = catResponse['id'].toString();
        }
      }

      // 1. PERBAIKAN ZONA WAKTU: Konversi waktu lokal ke UTC sebelum dilempar ke Supabase
      final dueObj = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute).toUtc();
      
      final payload = {
        'user_id': user!.id,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category_id': finalCategoryId,
        'due_date': dueObj.toIso8601String(),
      };

      if (widget.taskToEdit == null) {
        await Supabase.instance.client.from('tasks').insert(payload);
      } else {
        await Supabase.instance.client.from('tasks').update(payload).eq('id', widget.taskToEdit!['id']);
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Gagal simpan tugas: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    bool isValidCat = widget.categories.any((c) => c['id'].toString() == _selectedCategory);
    if (!isValidCat && widget.categories.isNotEmpty) _selectedCategory = widget.categories[0]['id'].toString();

    // 2. PERBAIKAN KEYBOARD NAIK: Bungkus margin bawah sesuai tinggi keyboard
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
            image: DecorationImage(image: AssetImage(isDarkMode ? 'assets/images/bg_card_dark.webp' : 'assets/images/bg_card.webp'), fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.2), blurRadius: 15, spreadRadius: 1)]),
                        child: Image.asset('assets/images/logo.webp', width: 44, height: 44),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.taskToEdit == null ? "Tambah Tugas Baru" : "Edit Detail Tugas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _titleController,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(labelText: "Judul Tugas *", labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent), filled: true, fillColor: isDarkMode ? Colors.black45 : Colors.white70, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                
                // 3. PERBAIKAN DROPDOWN: Dibuat elegan mirip input field React
                if (!_isCreatingCustomCat) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.black45 : Colors.white70, 
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer, size: 18, color: Colors.purpleAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    icon: Icon(Icons.keyboard_arrow_down, color: isDarkMode ? Colors.white54 : Colors.black54),
                                    dropdownColor: isDarkMode ? Colors.blueGrey.shade900 : Colors.white,
                                    items: widget.categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)))).toList(),
                                    onChanged: (v) => setState(() => _selectedCategory = v),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.add_circle, color: Colors.purpleAccent, size: 36), padding: EdgeInsets.zero, onPressed: () => setState(() => _isCreatingCustomCat = true))
                    ],
                  )
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDarkMode ? Colors.black45 : Colors.white70, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Kategori Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                            GestureDetector(onTap: () => setState(() => _isCreatingCustomCat = false), child: const Text("Batal", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)))
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(controller: _customCatController, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87), decoration: const InputDecoration(hintText: "Nama Kategori...", border: InputBorder.none, isDense: true)),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: _presetColors.map((color) => GestureDetector(onTap: () => setState(() => _selectedCustomColor = color), child: CircleAvatar(backgroundColor: color, radius: 12, child: _selectedCustomColor == color ? const Icon(Icons.check, size: 14, color: Colors.white) : null))).toList())
                      ],
                    ),
                  )
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (date != null) setState(() => _selectedDate = date);
                        },
                        child: Container(
                          height: 50, padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: isDarkMode ? Colors.black45 : Colors.white70, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
                          child: Row(children: [const Icon(Icons.calendar_month, size: 18, color: Colors.purpleAccent), const SizedBox(width: 8), Expanded(child: Text("${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}", overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)))])
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(context: context, initialTime: _selectedTime);
                          if (time != null) setState(() => _selectedTime = time);
                        },
                        child: Container(
                          height: 50, padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: isDarkMode ? Colors.black45 : Colors.white70, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade300)),
                          child: Row(children: [const Icon(Icons.access_time_filled, size: 18, color: Colors.purpleAccent), const SizedBox(width: 8), Expanded(child: Text("${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}", overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)))])
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: _descController, maxLines: 3,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(labelText: "Catatan (Opsional)", labelStyle: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54), filled: true, fillColor: isDarkMode ? Colors.black45 : Colors.white70, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: isDarkMode ? Colors.blueGrey.shade800 : Colors.grey.shade300, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text("Batal", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _saveData, style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Simpan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
