import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileHeaderCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isDarkMode;
  final Function(File) onImageSelect;
  final Function(String) onProfessionChange;
  final bool isUploadingAvatar;

  const ProfileHeaderCard({
    super.key,
    required this.user,
    required this.isDarkMode,
    required this.onImageSelect,
    required this.onProfessionChange,
    required this.isUploadingAvatar,
  });

  @override
  State<ProfileHeaderCard> createState() => _ProfileHeaderCardState();
}

class _ProfileHeaderCardState extends State<ProfileHeaderCard> {
  bool _isEditingProf = false;
  final TextEditingController _profController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profController.text = widget.user['stats']['profession'] ?? "";
  }

  @override
  void didUpdateWidget(covariant ProfileHeaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user['stats']['profession'] != widget.user['stats']['profession']) {
      _profController.text = widget.user['stats']['profession'] ?? "";
    }
  }

  void _handleSaveProfesi() {
    setState(() => _isEditingProf = false);
    final val = _profController.text.trim();
    if (val != widget.user['stats']['profession'] && val.isNotEmpty) {
      widget.onProfessionChange(val);
    }
  }

  Future<void> _pickImage() async {
    if (widget.isUploadingAvatar) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      widget.onImageSelect(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // BAGIAN ATAS: Foto, Nama, Bio, Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FOTO PROFIL & LOADER
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Colors.purpleAccent, Colors.indigoAccent], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isDarkMode ? Colors.blueGrey.shade900 : Colors.white, width: 2),
                          image: DecorationImage(
                            image: NetworkImage(widget.user['avatarUrl']),
                            fit: BoxFit.cover,
                            colorFilter: widget.isUploadingAvatar ? ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken) : null,
                          ),
                        ),
                      ),
                    ),
                    if (widget.isUploadingAvatar)
                      const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // NAMA DAN BIODATA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(widget.user['name'], overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium, size: 12, color: Colors.purpleAccent),
                              const SizedBox(width: 4),
                              Text(widget.user['badge'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("@${widget.user['username']} • ${widget.user['email']}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
                    const SizedBox(height: 8),
                    Text(widget.user['bio'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white70 : Colors.black87)),
                  ],
                ),
              )
            ],
          ),
          
          const SizedBox(height: 20),
          Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 1),
          const SizedBox(height: 16),
          
          // BAGIAN BAWAH: Statistik (XP, Profesi, Tanggal Bergabung)
          Row(
            children: [
              _buildStatBox(isDarkMode, Icons.bolt, Colors.purpleAccent, "Total XP", widget.user['stats']['totalXP']),
              const SizedBox(width: 12),
              
              // KOTAK PROFESI (EDITABLE)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_isEditingProf) setState(() => _isEditingProf = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.work, size: 12, color: Colors.orangeAccent),
                            const SizedBox(width: 4),
                            const Text("PROFESI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _isEditingProf
                            ? SizedBox(
                                height: 20,
                                child: TextField(
                                  controller: _profController,
                                  autofocus: true,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                                  ),
                                  onSubmitted: (_) => _handleSaveProfesi(),
                                  onTapOutside: (_) => _handleSaveProfesi(),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(child: Text(widget.user['stats']['profession'], overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87))),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 10, color: Colors.purpleAccent),
                                ],
                              )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildStatBox(isDarkMode, Icons.calendar_month, Colors.blueAccent, "Bergabung", widget.user['stats']['joinedDate']),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(bool isDarkMode, IconData icon, Color iconColor, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: iconColor),
                const SizedBox(width: 4),
                Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
