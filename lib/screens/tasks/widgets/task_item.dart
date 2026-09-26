import 'package:flutter/material.dart';

class TaskItemCard extends StatelessWidget {
  final dynamic task;
  final bool isDarkMode;
  final Color catColor;
  final String catName;
  final Function(String, bool) onToggle;
  final Function(dynamic)? onEdit;
  final Function(String)? onDelete;
  final bool showActions; // Kunci untuk menyembunyikan aksi di Kalender

  const TaskItemCard({
    super.key,
    required this.task,
    required this.isDarkMode,
    required this.catColor,
    required this.catName,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
    this.showActions = true, // Defaultnya true (muncul di halaman Tasks)
  });

  @override
  Widget build(BuildContext context) {
    String timeStr = "09:00";
    String dateStr = "Hari Ini";
    if (task['due_date'] != null) {
      final d = DateTime.parse(task['due_date']).toLocal();
      timeStr = "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
      const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Ags", "Sep", "Okt", "Nov", "Des"];
      dateStr = "${d.day} ${months[d.month - 1]}";
    }

    final isCompleted = task['is_completed'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blueGrey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200)
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onToggle(task['id'], isCompleted),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.circle_outlined, 
              color: isCompleted ? Colors.green : Colors.grey, 
              size: 26 
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] ?? 'Tanpa Judul',
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold, 
                    decoration: isCompleted ? TextDecoration.lineThrough : null, 
                    color: isCompleted ? (isDarkMode ? Colors.white38 : Colors.black38) : (isDarkMode ? Colors.white : Colors.black87)
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 4),
                    Text("$timeStr • $dateStr", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black45)),
                  ],
                )
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.15), 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: catColor.withOpacity(0.3))
            ),
            child: Text(catName.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: catColor)),
          ),
          
          // JIKA SHOW ACTIONS TRUE, MUNCULKAN TOMBOL EDIT & HAPUS
          if (showActions && onEdit != null && onDelete != null) ...[
            const SizedBox(width: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => onEdit!(task),
                  child: Icon(Icons.edit_outlined, size: 24, color: isDarkMode ? Colors.white70 : Colors.black54), 
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => onDelete!(task['id']),
                  child: const Icon(Icons.delete_outline, size: 24, color: Colors.redAccent), 
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
