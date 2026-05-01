import 'dart:io';
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
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final path = '$folder/$fileName';

    await _client.storage.from(_bucketName).upload(
      path,
      file,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }
}
