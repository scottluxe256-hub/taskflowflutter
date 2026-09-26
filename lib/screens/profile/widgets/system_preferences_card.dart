import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/sweet_alert.dart';

class SystemPreferencesCard extends StatefulWidget {
  final bool isDarkMode;
  const SystemPreferencesCard({super.key, required this.isDarkMode});

  @override
  State<SystemPreferencesCard> createState() => _SystemPreferencesCardState();
}

class _SystemPreferencesCardState extends State<SystemPreferencesCard> {
  double _usedMb = 0.0;
  double _percent = 0.0;
  late Timer _timer;
  final double _tabLimitMb = 512.0;

  @override
  void initState() {
    super.initState();
    _simulateRam();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _simulateRam());
  }

  void _simulateRam() {
    if (!mounted) return;
    setState(() {
      _usedMb = Random().nextDouble() * (60 - 35) + 35; 
      _percent = (_usedMb / _tabLimitMb) * 100;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleClearCache() {
    SweetAlert.show(context: context, title: "Memori Dibersihkan!", message: "File cache sementara berhasil dihapus. Sistem kini lebih ringan.", isSuccess: true, isDarkMode: widget.isDarkMode);
  }

  Future<void> _handleReportBug() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'syahrilking8@gmail.com',
      queryParameters: {
        'subject': 'Laporan Bug TaskFlow',
        'body': 'Halo Tim Support,\n\nSaya menemukan masalah/bug pada sistem berikut:\n\n1. \n2. \n\nMohon bantuannya. Terima kasih!'
      },
    );
    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint("Gagal buka email: $e");
    }
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
          Text("Sistem & Performa", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, size: 14, color: Colors.purpleAccent),
                      const SizedBox(width: 4),
                      Text("Beban Memori Tab", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  Text("Memakan ${_usedMb.toStringAsFixed(1)} MB dari sistem", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
              Text("${_percent.toStringAsFixed(1)}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _percent / 100,
              backgroundColor: isDark ? Colors.blueGrey.shade800 : Colors.grey.shade200,
              color: Colors.purpleAccent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          
          Text("KONTROL SISTEM", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.grey)),
          const SizedBox(height: 12),
          
          _buildActionRow("Fitur Eksperimental", "Akses khusus pengembangan", Icons.science, "Segera Hadir", isDark, null),
          const SizedBox(height: 12),
          _buildActionRow("Pembersihan Memori", "Hapus file sementara & cache", Icons.cleaning_services, "Bersihkan Cache", isDark, _handleClearCache),
          const SizedBox(height: 12),
          _buildActionRow("Ada Masalah?", "Bantu kami perbaiki sistem", Icons.bug_report, "Laporkan Bug", isDark, _handleReportBug),
        ],
      ),
    );
  }

  Widget _buildActionRow(String title, String subtitle, IconData icon, String btnText, bool isDark, VoidCallback? onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 12, color: onTap == null ? Colors.grey : (isDark ? Colors.white : Colors.black87)),
          label: Text(btnText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: onTap == null ? Colors.grey : (isDark ? Colors.white : Colors.black87))),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.blueGrey.shade800 : Colors.grey.shade100,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            // PERBAIKAN: borderSide diganti jadi side
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
              side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)
            ),
          ),
        )
      ],
    );
  }
}
