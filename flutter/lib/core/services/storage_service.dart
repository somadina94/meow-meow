import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';

/// Storage Service Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Storage Service
/// 
/// Handles file uploads and storage operations with Supabase Storage.
class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Upload profile photo
  Future<String?> uploadProfilePhoto({
    required String userId,
    required File file,
  }) async {
    try {
      final extension = file.path.split('.').last;
      final fileName = '${userId}_${_uuid.v4()}.$extension';
      final path = '$userId/$fileName';

      await _client.storage.from(SupabaseConfig.profilePhotosBucket).upload(
        path,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      return _client.storage
          .from(SupabaseConfig.profilePhotosBucket)
          .getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  /// Upload profile photo from bytes
  Future<String?> uploadProfilePhotoBytes({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    try {
      final fileName = '${userId}_${_uuid.v4()}.$extension';
      final path = '$userId/$fileName';

      await _client.storage.from(SupabaseConfig.profilePhotosBucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      return _client.storage
          .from(SupabaseConfig.profilePhotosBucket)
          .getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  /// Upload voice message
  Future<String?> uploadVoiceMessage({
    required String chatId,
    required File file,
  }) async {
    try {
      final fileName = '${chatId}_${_uuid.v4()}.m4a';
      final path = '$chatId/$fileName';

      await _client.storage.from(SupabaseConfig.voiceMessagesBucket).upload(
        path,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
        ),
      );

      return _client.storage
          .from(SupabaseConfig.voiceMessagesBucket)
          .getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  /// Delete file
  Future<bool> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await _client.storage.from(bucket).remove([path]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get signed URL (for private files)
  Future<String?> getSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    try {
      return await _client.storage.from(bucket).createSignedUrl(
        path,
        expiresIn,
      );
    } catch (e) {
      return null;
    }
  }

  /// List files in a folder
  Future<List<FileObject>> listFiles({
    required String bucket,
    required String path,
  }) async {
    try {
      return await _client.storage.from(bucket).list(path: path);
    } catch (e) {
      return [];
    }
  }
}
