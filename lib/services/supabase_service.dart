import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String _url = 'https://anelzjwwsogaxogjvgvw.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFuZWx6and3c29nYXhvZ2p2Z3Z3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NDY4MzYsImV4cCI6MjA5MzEyMjgzNn0.JeeAXniZ7zTYbm0E6P0ylxs0WUorsC8i7-KMUTE6J8I';
  static const String _bucketName = 'task-assets';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
    );
  }

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<String> uploadFile(String folder, File file) async {
    try {
      debugPrint('--- SUPABASE UPLOAD START ---');
      debugPrint('Folder: $folder');
      debugPrint('File path: ${file.path}');
      
      if (!await file.exists()) {
        debugPrint('Error: File does not exist at path ${file.path}');
        throw Exception('File does not exist');
      }

      // Robust filename extraction
      final originalName = file.path.split(RegExp(r'[/\\]')).last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final path = '$folder/$fileName';
      
      debugPrint('Uploading to: $path');

      await _client.storage.from(_bucketName).upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      ).timeout(const Duration(seconds: 60), onTimeout: () {
        debugPrint('Supabase upload timed out after 60s');
        throw Exception('Upload timed out. Please check your internet connection.');
      });

      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(path);
      debugPrint('Upload successful! Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('--- SUPABASE UPLOAD ERROR ---');
      debugPrint('Error: $e');
      rethrow;
    }
  }
}
