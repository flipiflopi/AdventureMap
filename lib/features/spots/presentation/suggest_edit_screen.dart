// lib/features/spots/presentation/suggest_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../models/spot_model.dart';
import '../../../models/spot_suggestion_model.dart';
import '../../../providers/providers.dart';
import '../../../services/image_compression_service.dart';

class SuggestEditScreen extends ConsumerStatefulWidget {
  final SpotModel spot;

  const SuggestEditScreen({Key? key, required this.spot}) : super(key: key);

  @override
  ConsumerState<SuggestEditScreen> createState() => _SuggestEditScreenState();
}

class _SuggestEditScreenState extends ConsumerState<SuggestEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _detailsController;
  late final TextEditingController _accessController;
  late final TextEditingController _safetyController;

  final _picker = ImagePicker();
  List<File> _newImages = [];
  bool _isSubmitting = false;

  int _selectedDescriptionTab = 0;

  @override
  void initState() {
    super.initState();
    _detailsController = TextEditingController(text: widget.spot.details);
    _accessController = TextEditingController(text: widget.spot.access);
    _safetyController = TextEditingController(text: widget.spot.safety);
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _accessController.dispose();
    _safetyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;
    if (_newImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxPhotosSuggestion)),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(l10n.compressingImages(1)),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final compressedFile = await ImageCompressionService.compressImage(
        File(image.path),
      );

      if (compressedFile != null) {
        setState(() {
          _newImages.add(compressedFile);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.imageAddedSuccess),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    if (_newImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxPhotosSuggestion)),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
    );

    if (image != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(l10n.compressingImages(1)),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final compressedFile = await ImageCompressionService.compressImage(
        File(image.path),
      );

      if (compressedFile != null) {
        setState(() {
          _newImages.add(compressedFile);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.photoTakenSuccess),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadNewPhotos() async {
    final List<String> photoUrls = [];
    print('📤 Subiendo ${_newImages.length} fotos sugeridas...');

    for (var i = 0; i < _newImages.length; i++) {
      try {
        final image = _newImages[i];
        final fileName =
            'suggestions/${widget.spot.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        await ref.putFile(image);
        final url = await ref.getDownloadURL();
        photoUrls.add(url);
      } catch (e) {
        print('❌ Error subiendo foto: $e');
      }
    }
    return photoUrls;
  }

  Future<void> _submitSuggestion() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final hasDetailsChange = _detailsController.text.trim() != widget.spot.details;
    final hasAccessChange = _accessController.text.trim() != widget.spot.access;
    final hasSafetyChange = _safetyController.text.trim() != widget.spot.safety;
    final hasNewPhotos = _newImages.isNotEmpty;

    if (!hasDetailsChange && !hasAccessChange && !hasSafetyChange && !hasNewPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.atLeastOneChangeRequired)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final photoUrls = await _uploadNewPhotos();

      String? combinedDescription;
      if (hasDetailsChange || hasAccessChange || hasSafetyChange) {
        combinedDescription = '''
${l10n.detailsTab.toUpperCase()}:
${_detailsController.text.trim()}

${l10n.accessTab.toUpperCase()}:
${_accessController.text.trim()}

${l10n.safetyTab.toUpperCase()}:
${_safetyController.text.trim()}
''';
      }

      final suggestion = SpotSuggestion(
        id: '',
        spotId: widget.spot.id,
        suggestedBy: currentUser.uid,
        newDescription: combinedDescription,
        newPhotoUrls: photoUrls,
        createdAt: DateTime.now(),
      );

      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.createSuggestion(suggestion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.suggestionSentSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suggestEditTitle),
        backgroundColor: Colors.blue,
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitSuggestion,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            l10n.originalSpot,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(widget.spot.category.icon,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.spot.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.suggestImprovementDesc,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.editTabsInstruction,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildDescriptionTabs(l10n),
              const SizedBox(height: 24),
              Text(
                l10n.newPhotosOptional,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.addUpTo3Photos,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (_newImages.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _newImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _newImages[index],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.red,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _newImages.length < 3 ? _pickImage : null,
                      icon: const Icon(Icons.photo_library),
                      label: Text(l10n.gallery),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _newImages.length < 3 ? _takePhoto : null,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(l10n.camera),
                    ),
                  ),
                ],
              ),
              if (_newImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.photosAddedCount(_newImages.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Card(
                color: Colors.amber[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pending_actions,
                              color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            l10n.howItWorks,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.howItWorksStep1}\n'
                            '${l10n.howItWorksStep2}\n'
                            '${l10n.howItWorksStep3}\n'
                            '${l10n.howItWorksStep4}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionTabs(AppLocalizations l10n) {
    return Card(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                _buildTab(l10n.detailsTab, 0, Icons.description),
                _buildTab(l10n.accessTab, 1, Icons.directions_car),
                _buildTab(l10n.safetyTab, 2, Icons.warning_amber),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTabContent(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, IconData icon) {
    final isSelected = _selectedDescriptionTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDescriptionTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(AppLocalizations l10n) {
    TextEditingController controller;
    String label;
    String hint;

    switch (_selectedDescriptionTab) {
      case 0:
        controller = _detailsController;
        label = l10n.detailsLabel;
        hint = l10n.detailsImproveHint;
        break;
      case 1:
        controller = _accessController;
        label = l10n.accessLabel;
        hint = l10n.accessImproveHint;
        break;
      case 2:
        controller = _safetyController;
        label = l10n.safetyLabel;
        hint = l10n.safetyImproveHint;
        break;
      default:
        controller = _detailsController;
        label = l10n.detailsTab;
        hint = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    l10n.currentText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _getOriginalText(l10n),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          maxLines: 6,
          maxLength: 600,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  String _getOriginalText(AppLocalizations l10n) {
    switch (_selectedDescriptionTab) {
      case 0:
        return widget.spot.details.isEmpty ? l10n.noDetailsInfo : widget.spot.details;
      case 1:
        return widget.spot.access.isEmpty ? l10n.noAccessInfo : widget.spot.access;
      case 2:
        return widget.spot.safety.isEmpty ? l10n.noSafetyInfo : widget.spot.safety;
      default:
        return '';
    }
  }
}