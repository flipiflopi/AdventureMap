// lib/features/spots/presentation/edit_spot_screen.dart
import 'dart:io';
import 'dart:math' as math; 
import 'package:adventure_map/models/spot_suggestion_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../models/spot_model.dart';
import '../../../providers/providers.dart';
import '../../../services/content_moderation_service.dart';
import '../../../services/image_compression_service.dart';

class EditSpotScreen extends ConsumerStatefulWidget {
  final SpotModel spot;

  const EditSpotScreen({Key? key, required this.spot}) : super(key: key);

  @override
  ConsumerState<EditSpotScreen> createState() => _EditSpotScreenState();
}

class _EditSpotScreenState extends ConsumerState<EditSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _detailsController;
  late final TextEditingController _accessController;
  late final TextEditingController _safetyController;

  final _picker = ImagePicker();

  late SpotCategory _selectedCategory;
  List<String> _existingPhotoUrls = [];
  List<File> _newImages = [];
  bool _isSubmitting = false;

  int _selectedDescriptionTab = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.spot.name);
    _detailsController = TextEditingController(text: widget.spot.details);
    _accessController = TextEditingController(text: widget.spot.access);
    _safetyController = TextEditingController(text: widget.spot.safety);
    _selectedCategory = widget.spot.category;
    _existingPhotoUrls = List.from(widget.spot.photoUrls);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _accessController.dispose();
    _safetyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;
    final totalPhotos = _existingPhotoUrls.length + _newImages.length;

    if (totalPhotos >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxPhotosError)),
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
    final totalPhotos = _existingPhotoUrls.length + _newImages.length;

    if (totalPhotos >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxPhotosError)),
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

  void _removeExistingPhoto(int index) {
    setState(() {
      if (index >= 0 && index < _existingPhotoUrls.length) {
        _existingPhotoUrls.removeAt(index);
      }
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      if (index >= 0 && index < _newImages.length) {
        _newImages.removeAt(index);
      }
    });
  }

  Future<List<String>> _uploadNewPhotos() async {
    final List<String> photoUrls = [];

    print('📤 Subiendo ${_newImages.length} fotos comprimidas...');

    for (var i = 0; i < _newImages.length; i++) {
      try {
        final image = _newImages[i];
        print('   📸 Subiendo foto ${i + 1}/${_newImages.length}...');

        final fileName =
            'spots/${widget.spot.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        await ref.putFile(image);
        final url = await ref.getDownloadURL();
        photoUrls.add(url);

        print('   ✅ Foto ${i + 1} subida correctamente');
      } catch (e) {
        print('   ❌ Error subiendo foto ${i + 1}: $e');
      }
    }

    print('✅ Fotos nuevas subidas (${photoUrls.length}/${_newImages.length})');
    return photoUrls;
  }

  Future<void> _saveChanges() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final totalPhotos = _existingPhotoUrls.length + _newImages.length;
    if (totalPhotos == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.atLeastOnePhotoError)),
      );
      return;
    }

    final detailsValidation = ContentModerationService.validateSpotContent(
      name: _nameController.text.trim(),
      description: _detailsController.text.trim(),
    );

    final accessValidation = ContentModerationService.validateSpotContent(
      name: '',
      description: _accessController.text.trim(),
    );

    final safetyValidation = ContentModerationService.validateSpotContent(
      name: '',
      description: _safetyController.text.trim(),
    );

    final validations = [detailsValidation, accessValidation, safetyValidation];
    final failedValidation = validations.firstWhere(
      (v) => !v.isClean,
      orElse: () => detailsValidation,
    );

    bool shouldSendToModeration = false;

    if (!failedValidation.isClean) {
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 8),
              Text(l10n.contentDetectedTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.contentDetectedDesc,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  l10n.errorMistakeModeration,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.reviewText),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.send),
              label: Text(l10n.sendToModeration),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      if (result == true) {
        shouldSendToModeration = true;
      } else {
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final newUrls = await _uploadNewPhotos();
      final allPhotoUrls = [..._existingPhotoUrls, ...newUrls];
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      if (shouldSendToModeration) {
        final pendingSpot = PendingSpot(
          id: '',
          name: _nameController.text.trim(),
          description: _detailsController.text.trim(),
          access: _accessController.text.trim(),
          safety: _safetyController.text.trim(),
          category: _selectedCategory.name,
          latitude: widget.spot.latitude,
          longitude: widget.spot.longitude,
          photoUrls: allPhotoUrls,
          createdBy: currentUser?.uid ?? '',
          createdAt: DateTime.now(),
        );

        await firestoreService.createPendingSpot(pendingSpot);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.editPendingNotice),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final updateData = {
          'name': _nameController.text.trim(),
          'details': _detailsController.text.trim(),
          'access': _accessController.text.trim(),
          'safety': _safetyController.text.trim(),
          'category': _selectedCategory.name,
          'photoUrls': allPhotoUrls,
        };

        await firestoreService.updateSpot(widget.spot.id, updateData);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.spotUpdatedSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editSpot),
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
              icon: const Icon(Icons.check),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.placeNameLabel,
                  prefixIcon: const Icon(Icons.place),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.placeNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildDescriptionTabs(l10n),
              const SizedBox(height: 20),
              _buildCategorySelector(l10n),
              const SizedBox(height: 20),
              _buildPhotosSection(l10n),
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
    bool isRequired;

    switch (_selectedDescriptionTab) {
      case 0:
        controller = _detailsController;
        label = l10n.detailsLabel;
        hint = l10n.detailsHint;
        isRequired = true;
        break;
      case 1:
        controller = _accessController;
        label = l10n.accessLabel;
        hint = l10n.accessHint;
        isRequired = false;
        break;
      case 2:
        controller = _safetyController;
        label = l10n.safetyLabel;
        hint = l10n.safetyHint;
        isRequired = false;
        break;
      default:
        controller = _detailsController;
        label = l10n.detailsTab;
        hint = '';
        isRequired = true;
    }

    return TextFormField(
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
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.requiredField;
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildCategorySelector(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.categoryLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SpotCategory.values.map((category) {
                final isSelected = category == _selectedCategory;
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.icon),
                      const SizedBox(width: 4),
                      Text(category.getLocalizedName(context)),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection(AppLocalizations l10n) {
    final totalPhotos = _existingPhotoUrls.length + _newImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.photosCountLabel(totalPhotos),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (_existingPhotoUrls.isNotEmpty) ...[
          Text(
            l10n.currentPhotos,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingPhotoUrls.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _existingPhotoUrls[index],
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
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () => _removeExistingPhoto(index),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_newImages.isNotEmpty) ...[
          Text(
            l10n.newPhotos,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
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
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () => _removeNewImage(index),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.newBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: totalPhotos < 5 ? _pickImage : null,
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.gallery),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: totalPhotos < 5 ? _takePhoto : null,
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.camera),
              ),
            ),
          ],
        ),
      ],
    );
  }
}