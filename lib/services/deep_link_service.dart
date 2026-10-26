// lib/services/deep_link_service.dart
import 'dart:async';
import 'package:flutter/services.dart';

class DeepLinkService {
  static const platform = MethodChannel('app.adventuremap/deeplink');

  Stream<String> get deepLinkStream {
    return const EventChannel('app.adventuremap/deeplink_stream')
        .receiveBroadcastStream()
        .cast<String>();
  }

  Future<String?> getInitialLink() async {
    try {
      final String? link = await platform.invokeMethod('getInitialLink');
      return link;
    } on PlatformException {
      return null;
    }
  }

  static String? extractFolderIdFromLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    if (uri.scheme == 'https' && uri.host == 'adventuremap.app') {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'folder') {
        return segments[1];
      }
    }

    if (uri.scheme == 'adventuremap' && uri.host == 'folder') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments[0];
      }
    }
    return null;
  }

  static String generateFolderShareLink(String folderId) {
    return 'adventuremap://folder/$folderId';
  }

  // 🔄 CAMBIO: El método ahora es más genérico y solo devuelve el link si es necesario,
  // o recibe el texto ya localizado desde la UI.
  static String generateShareText({
    required String localizedMessage,
  }) {
    return localizedMessage;
  }
}