import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class CloudinaryHelper {
  static const String cloudName = "z1awtcu6"; // Cloud name lu
  static const String uploadPreset = "taskflow_profil"; // Preset lu
  // URL API Cloudflare Pages lu buat delete image (Jalur Senyap)
  static const String deleteApiUrl = "https://taskflow-2gq.pages.dev/api/delete-image";

  // 1. Fungsi Upload File ke Cloudinary
  static Future<String?> uploadToCloudinary(File file) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseData);
        return data['secure_url']; // Dapat URL asli Cloudinary
      } else {
        debugPrint("Cloudinary Upload Error: $responseData");
        return null;
      }
    } catch (e) {
      debugPrint("Gagal upload: $e");
      return null;
    }
  }

  // 2. Fungsi Optimasi AI & Crop (Persis kayak di React)
  static String getOptimizedImageUrl(String url, {String format = "f_avif"}) {
    if (url.isEmpty) return "";
    
    // c_thumb, g_auto (AI pencari wajah), ubah ke 400x400
    final optimizationParams = "c_thumb,g_auto,w_400,h_400,$format";
    return url.replaceFirst("/upload/", "/upload/$optimizationParams/");
  }

  // 3. Fungsi Delete Foto Lama via API Cloudflare (JALUR SENYAP)
  static Future<void> deleteOldImage(String oldAvatarUrl) async {
    if (oldAvatarUrl.isEmpty || !oldAvatarUrl.contains("cloudinary.com")) return;

    try {
      // Ekstrak public_id dari URL
      // Contoh URL: https://res.cloudinary.com/.../upload/v1234/abcdef1234.avif
      final uri = Uri.parse(oldAvatarUrl);
      final segments = uri.pathSegments;
      final lastSegment = segments.last; // abcdef1234.avif
      final publicId = lastSegment.split('.').first; // abcdef1234

      // Tembak API Cloudflare di background (tanpa await yang ditunggu banget)
      http.post(
        Uri.parse(deleteApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'public_id': publicId}),
      ).then((response) {
        if (response.statusCode == 200) {
          debugPrint("✅ Foto lama [$publicId] sukses dimusnahkan di background.");
        } else {
          debugPrint("⚠️ Gagal hapus foto lama: ${response.body}");
        }
      }).catchError((err) {
        debugPrint("❌ API Hapus Foto Error: $err");
      });
      
    } catch (e) {
      debugPrint("Gagal ekstrak ID foto lama: $e");
    }
  }
}
