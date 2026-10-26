// lib/services/folder_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/folder_model.dart';
import '../models/spot_model.dart';

class FolderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener todas las carpetas del usuario
  Stream<List<FolderModel>> getUserFolders(String userId) {
    return _firestore
        .collection('folders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => FolderModel.fromFirestore(doc))
        .toList());
  }

  // Crear carpeta
  Future<String> createFolder(FolderModel folder) async {
    final docRef = await _firestore.collection('folders').add(folder.toFirestore());
    return docRef.id;
  }

  // Actualizar carpeta
  Future<void> updateFolder(FolderModel folder) async {
    await _firestore.collection('folders').doc(folder.id).update(folder.toFirestore());
  }

  // Eliminar carpeta
  Future<void> deleteFolder(String folderId) async {
    await _firestore.collection('folders').doc(folderId).delete();
  }

  // Agregar spot a carpeta
  Future<void> addSpotToFolder(String folderId, String spotId) async {
    await _firestore.collection('folders').doc(folderId).update({
      'spotIds': FieldValue.arrayUnion([spotId]),
    });
  }

  // Remover spot de carpeta
  Future<void> removeSpotFromFolder(String folderId, String spotId) async {
    await _firestore.collection('folders').doc(folderId).update({
      'spotIds': FieldValue.arrayRemove([spotId]),
    });
  }

  // Obtener spots de una carpeta
  // lib/services/folder_service.dart

// ... existing imports and class definition ...

  // Obtener spots de una carpeta
  // FIX: Change to return a Stream<List<SpotModel>>
  Stream<List<SpotModel>> getFolderSpotsStream(String folderId) {
    // 1. Stream the folder document to get real-time updates of spotIds
    return _firestore.collection('folders').doc(folderId).snapshots().asyncMap((folderDoc) async {
      if (!folderDoc.exists) return [];

      final folder = FolderModel.fromFirestore(folderDoc);
      if (folder.spotIds.isEmpty) return [];

      // 2. Fetch the spots based on the list of spotIds
      // NOTE: Firestore limits 'whereIn' to 10 elements. If you expect more,
      // you'll need to split this query into batches or change your data structure.
      final spotsSnapshot = await _firestore
          .collection('spots')
          .where(FieldPath.documentId, whereIn: folder.spotIds.take(10).toList()) // Use .take(10) to respect Firestore limit
          .get();

      return spotsSnapshot.docs
          .map((doc) => SpotModel.fromFirestore(doc))
          .toList();
    });
  }
// ... rest of FolderService ...

  // Añadir este método a tu folder_service.dart
  Future<FolderModel?> getFolderById(String folderId) async {
    try {
      final doc = await _firestore.collection('folders').doc(folderId).get();
      if (doc.exists) {
        return FolderModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting folder by ID: $e');
      return null;
    }
  }
  // Verificar si un spot está en alguna carpeta
  Future<List<FolderModel>> getFoldersContainingSpot(String userId, String spotId) async {
    final snapshot = await _firestore
        .collection('folders')
        .where('userId', isEqualTo: userId)
        .where('spotIds', arrayContains: spotId)
        .get();

    return snapshot.docs
        .map((doc) => FolderModel.fromFirestore(doc))
        .toList();
  }
}