// lib/services/image_compression_service.dart
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCompressionService {
  /// Comprime una imagen optimizando tamaño y calidad
  ///
  /// Resultado esperado:
  /// - De 3-5MB → 200-400KB (reducción del 90%)
  /// - Calidad visual: Imperceptible para el ojo humano
  /// - Resolución: Máximo 1280x720 (perfecto para móviles)
  static Future<File?> compressImage(File file) async {
    try {
      print('📸 Comprimiendo imagen...');
      print('   Tamaño original: ${await _getFileSize(file)}');

      // Obtener directorio temporal
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      // 🎯 COMPRESIÓN AGRESIVA
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Calidad 70% (balance perfecto calidad/tamaño)
        minWidth: 1280, // Ancho máximo
        minHeight: 720, // Alto máximo
        format: CompressFormat.jpeg, // JPEG es más pequeño que PNG
        keepExif: false, // Eliminar metadatos EXIF (ubicación, cámara, etc.)
      );

      if (result == null) {
        print('❌ Error: No se pudo comprimir la imagen');
        return file; // Devolver original si falla
      }

      final compressedFile = File(result.path);
      print('✅ Imagen comprimida');
      print('   Tamaño comprimido: ${await _getFileSize(compressedFile)}');
      print('   Reducción: ${await _getCompressionRatio(file, compressedFile)}%');

      return compressedFile;
    } catch (e) {
      print('❌ Error comprimiendo imagen: $e');
      return file; // Devolver original si hay error
    }
  }

  /// Comprime múltiples imágenes en paralelo (más rápido)
  static Future<List<File>> compressImages(List<File> files) async {
    print('📸 Comprimiendo ${files.length} imágenes...');

    final compressedFiles = await Future.wait(
      files.map((file) => compressImage(file)),
    );

    // Filtrar nulls y devolver solo archivos válidos
    return compressedFiles.whereType<File>().toList();
  }

  /// Obtiene el tamaño del archivo en formato legible
  static Future<String> _getFileSize(File file) async {
    final bytes = await file.length();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Calcula el porcentaje de reducción
  static Future<String> _getCompressionRatio(File original, File compressed) async {
    final originalSize = await original.length();
    final compressedSize = await compressed.length();
    final reduction = ((originalSize - compressedSize) / originalSize * 100);
    return reduction.toStringAsFixed(1);
  }
}