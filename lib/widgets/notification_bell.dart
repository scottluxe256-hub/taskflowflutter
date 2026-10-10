import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationBell extends StatefulWidget {
  final bool isDarkMode;
  const NotificationBell({super.key, required this.isDarkMode});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<Map<String, dynamic>> _notifications = [];
  Timer? _timer;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchNotifications());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Ambil preferensi durasi dari profil user
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('reminder_duration')
          .eq('id', user.id)
          .maybeSingle();

      String durationStr = profileRes?['reminder_duration']?.toString() ?? "15 Menit";
      int thresholdMs = 15 * 60 * 1000;

      // 2. Konversi string durasi menjadi milidetik
      final parts = durationStr.split(" ");
      if (parts.length == 2) {
        final val = int.tryParse(parts[0]);
        final unit = parts[1].toLowerCase();
        if (val != null) {
          if (unit == "menit") thresholdMs = val * 60 * 1000;
          else if (unit == "jam") thresholdMs = val * 60 * 60 * 1000;
          else if (unit == "hari") thresholdMs = val * 24 * 60 * 60 * 1000;
        }
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      // 3. Tarik tugas hari ini
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('id, title, due_date')
          .eq('user_id', user.id)
          .eq('is_completed', false)
          .eq('is_hidden', false)
          .not('due_date', 'is', 'null')
          .gte('due_date', startOfDay)
          .lte('due_date', endOfDay)
          .order('due_date', ascending: true);

      final prefs = await SharedPreferences.getInstance();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      final lastClearedDate = prefs.getString('taskflow_notif_date');
      List<String> readNotifs = prefs.getStringList('taskflow_read_notifs') ?? [];

      if (lastClearedDate != todayStr) {
        readNotifs = [];
        await prefs.setStringList('taskflow_read_notifs', []);
        await prefs.setString('taskflow_notif_date', todayStr);
      }

      final nowMs = now.millisecondsSinceEpoch;
      List<Map<String, dynamic>> activeNotifs = [];

      // 4. Saring berdasarkan threshold waktu
      for (var task in tasks) {
        final dueDate = DateTime.parse(task['due_date'].toString()).toLocal();
        final dueMs = dueDate.millisecondsSinceEpoch;

        if ((dueMs - nowMs) <= thresholdMs) {
          activeNotifs.add({
            'id': task['id'].toString(),
            'title': task['title'],
            'time': "${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}",
            'isOverdue': nowMs > dueMs,
            'isRead': readNotifs.contains(task['id'].toString()),
          });
        }
      }

      if (mounted) {
        setState(() {
          _notifications = activeNotifs;
          _unreadCount = _notifications.where((n) => n['isRead'] == false).length;
        });
      }
    } catch (e) {
      debugPrint("Gagal load notifikasi: $e");
    }
  }

  Future<void> _markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final allIds = _notifications.map((n) => n['id'].toString()).toList();
    await prefs.setStringList('taskflow_read_notifs', allIds);
    if (mounted) {
      setState(() {
        for (var n in _notifications) {
          n['isRead'] = true;
        }
        _unreadCount = 0;
      });
    }
  }

  void _showNotificationDropdown(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'NotificationDismiss',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top - 8,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 310,
                  constraints: const BoxConstraints(maxHeight: 380),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF0F172A).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 25, offset: const Offset(0, 10))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Notifikasi",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (_unreadCount > 0)
                                GestureDetector(
                                  onTap: _markAllRead,
                                  child: const Row(
                                    children: [
                                      Icon(Icons.done_all, size: 14, color: Colors.purpleAccent),
                                      SizedBox(width: 4),
                                      Text(
                                        "Baca Semua",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purpleAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                            ],
                          ),
                        ),
                        Flexible(
                          child: _notifications.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 36),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: 32,
                                        color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Belum ada notifikasi tenggat waktu.",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _notifications.length,
                                  itemBuilder: (context, index) {
                                    final notif = _notifications[index];
                                    final bool isUnread = !notif['isRead'];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isUnread
                                            ? (widget.isDarkMode
                                                ? Colors.purpleAccent.withOpacity(0.15)
                                                : Colors.purpleAccent.withOpacity(0.08))
                                            : Colors.transparent,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: widget.isDarkMode ? Colors.white10 : Colors.grey.shade100,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 4, right: 10),
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isUnread ? Colors.purpleAccent : Colors.transparent,
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  notif['title'],
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: widget.isDarkMode
                                                        ? (isUnread ? Colors.white : Colors.white70)
                                                        : (isUnread ? Colors.black87 : Colors.black54),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time_rounded,
                                                      size: 11,
                                                      color: widget.isDarkMode ? Colors.white54 : Colors.black45,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      notif['time'],
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: widget.isDarkMode ? Colors.white54 : Colors.black45,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: notif['isOverdue']
                                                            ? Colors.redAccent.withOpacity(0.15)
                                                            : Colors.amber.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        notif['isOverdue'] ? "Melewati Tenggat!" : "Segera Berakhir!",
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: notif['isOverdue'] ? Colors.redAccent : Colors.amber.shade700,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                )
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showNotificationDropdown(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 22,
              color: widget.isDarkMode ? Colors.white70 : Colors.black54,
            ),
            if (_unreadCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isDarkMode ? Colors.black : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _unreadCount > 9 ? "9+" : _unreadCount.toString(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
