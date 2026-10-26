// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String> uploadSpotImage(File imageFile, String spotId) async {
    try {
      final compressedFile = await _compressImage(imageFile);
      final fileName = '${_uuid.v4()}.jpg';
      final path = 'spots/$spotId/$fileName';

      final ref = _storage.ref().child(path);
      await ref.putFile(compressedFile);

      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      print('❌ Storage Error: ${e.code}');
      // 🔄 Lanzamos código técnico según el error de Firebase
      if (e.code == 'unauthorized') throw Exception('errorPermissionStorage');
      if (e.code == 'canceled') throw Exception('errorUploadFailed');
      throw Exception('errorUploadFailed');
    } catch (e) {
      throw Exception('errorUploadFailed');
    }
  }

  Future<String> uploadProfileImage(File imageFile, String userId) async {
    try {
      final compressedFile = await _compressImage(imageFile);
      final path = 'users/$userId/profile.jpg';

      final ref = _storage.ref().child(path);
      await ref.putFile(compressedFile);

      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized') throw Exception('errorPermissionStorage');
      throw Exception('errorUploadFailed');
    } catch (e) {
      throw Exception('errorUploadFailed');
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Image deleted successfully');
    } catch (e) {
      print('❌ Error deleting image: $e');
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${_uuid.v4()}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1920,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );

      if (result == null) return file;
      return File(result.path);
    } catch (e) {
      print('❌ Compression error: $e');
      return file;
    }
  }

  Future<List<String>> uploadMultipleSpotImages(List<File> images, String spotId) async {
    final List<String> urls = [];
    for (final image in images) {
      try {
        final url = await uploadSpotImage(image, spotId);
        urls.add(url);
      } catch (e) {
        print('❌ Error uploading one of the multiple images: $e');
      }
    }
    return urls;
  }

  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImage(url);
    }
  }
}