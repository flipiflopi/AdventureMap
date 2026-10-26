// lib/features/spots/presentation/create_spot_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../models/spot_model.dart';
import '../../../models/spot_suggestion_model.dart';
import '../../../providers/providers.dart';
import '../../../services/validation_service.dart';
import 'select_location_screen.dart';
import 'nearby_spots_dialog.dart';
import 'own_spots_dialog.dart';
import '../../../services/nominatim_service.dart';
import '../../../services/content_moderation_service.dart';
import '../../../services/image_compression_service.dart';

class CreateSpotScreen extends ConsumerStatefulWidget {
  const CreateSpotScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateSpotScreen> createState() => _CreateSpotScreenState();
}

class _CreateSpotScreenState extends ConsumerState<CreateSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final _detailsController = TextEditingController();
  final _accessController = TextEditingController();
  final _safetyController = TextEditingController();

  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  final _validationService = ValidationService();

  SpotCategory _selectedCategory = SpotCategory.other;
  List<File> _images = [];
  double? _latitude;
  double? _longitude;
  String? _selectedAddress;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  bool _sendToModeration = false;

  int _selectedDescriptionTab = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _accessController.dispose();
    _safetyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoadingLocation = true;
    });

    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentLocation();

    if (position != null) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    }

    setState(() {
      _isLoadingLocation = false;
    });

    if (position == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.locationError)),
      );
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final nominatim = NominatimService();
      final address = await nominatim.getAddressFromCoordinates(lat, lng);

      if (address != null) {
        setState(() {
          _selectedAddress = address;
          _locationController.text = address;
        });
      }
    } catch (e) {
      print('Error obteniendo dirección: $e');
    }
  }

  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });
      await _getAddressFromCoordinates(_latitude!, _longitude!);
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;
    if (_images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxPhotosError)),
      );
      return;
    }

    final List<XFile> selectedImages = await _picker.pickMultiImage();

    if (selectedImages.isEmpty) return;

    final remainingSlots = 5 - _images.length;
    final imagesToAdd = selectedImages.take(remainingSlots).toList();

    if (selectedImages.length > remainingSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.onlyPhotosAdded(imagesToAdd.length)),
          backgroundColor: Colors.orange,
        ),
      );
    }

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
              Text(l10n.compressingImages(imagesToAdd.length)),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    int successCount = 0;
    for (var xFile in imagesToAdd) {
      final compressedFile = await ImageCompressionService.compressImage(
        File(xFile.path),
      );

      if (compressedFile != null) {
        setState(() {
          _images.add(compressedFile);
        });
        successCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.imagesAddedSuccess(successCount)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    if (_images.length >= 5) {
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
          _images.add(compressedFile);
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
      _images.removeAt(index);
    });
  }

  Future<void> _validateAndCreateSpot() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectLocationError)),
      );
      return;
    }

    print('🔍 Validando contenido inapropiado...');

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

    if (!failedValidation.isClean) {
      print('❌ Contenido inapropiado detectado: ${failedValidation.detectedWord}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failedValidation.errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      final sendToModeration = await showDialog<bool>(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.errorMistakeTip,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.moderationOffer,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
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

      if (sendToModeration == true) {
        setState(() {
          _sendToModeration = true;
        });

        final currentUser = ref.read(currentUserProvider);
        if (currentUser == null) return;

        setState(() {
          _isSubmitting = true;
        });

        try {
          final validationResult = await _validationService.findNearbyOrSimilarSpots(
            latitude: _latitude!,
            longitude: _longitude!,
            name: _nameController.text.trim(),
            currentUserId: currentUser.uid,
          );

          setState(() {
            _isSubmitting = false;
          });

          if (validationResult.hasOwnSpots) {
            await showDialog(
              context: context,
              builder: (context) => OwnSpotsDialog(
                ownSpots: validationResult.ownSpots,
                proposedName: _nameController.text.trim(),
              ),
            );
            setState(() {
              _sendToModeration = false;
            });
            return;
          }

          if (validationResult.hasOtherUserSpots) {
            await showDialog(
              context: context,
              builder: (context) => NearbySpotsDialog(
                nearbySpots: validationResult.otherUserSpots,
                proposedName: _nameController.text.trim(),
                proposedLatitude: _latitude!,
                proposedLongitude: _longitude!,
                onCreateAnyway: () {
                  _createSpot();
                },
              ),
            );
            setState(() {
              _sendToModeration = false;
            });
            return;
          }

          await _createSpot();
        } catch (e) {
          setState(() {
            _isSubmitting = false;
            _sendToModeration = false;
          });
        }
        return;
      }
      return;
    }

    print('✅ Contenido validado - Sin palabras inapropiadas');

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      print('🔍 Iniciando validación de duplicados...');

      final validationResult = await _validationService.findNearbyOrSimilarSpots(
        latitude: _latitude!,
        longitude: _longitude!,
        name: _nameController.text.trim(),
        currentUserId: currentUser.uid,
      );

      print('✅ Validación completada');

      setState(() {
        _isSubmitting = false;
      });

      if (validationResult.hasOwnSpots && !_sendToModeration) {
        print('⚠️ Mostrando diálogo de spots propios');
        await showDialog(
          context: context,
          builder: (context) => OwnSpotsDialog(
            ownSpots: validationResult.ownSpots,
            proposedName: _nameController.text.trim(),
          ),
        );
        return;
      }

      if (validationResult.hasOtherUserSpots && !_sendToModeration) {
        print('⚠️ Mostrando diálogo de spots cercanos de otros usuarios');
        await showDialog(
          context: context,
          builder: (context) => NearbySpotsDialog(
            nearbySpots: validationResult.otherUserSpots,
            proposedName: _nameController.text.trim(),
            proposedLatitude: _latitude!,
            proposedLongitude: _longitude!,
            onCreateAnyway: () {
              setState(() {
                _sendToModeration = true;
              });
              _createSpot();
            },
          ),
        );
        return;
      }

      print('✅ No hay conflictos, creando spot...');
      await _createSpot();

    } catch (e, stackTrace) {
      print('❌ ERROR en validación: $e');
      print('📍 StackTrace: $stackTrace');

      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static const String _kDefaultPhotoStoragePath = 'spots/default_no_photo.jpg';

  Future<String> _getOrUploadDefaultPhoto() async {
    final ref = FirebaseStorage.instance.ref().child(_kDefaultPhotoStoragePath);
    try {
      // Reutilizar si ya existe
      return await ref.getDownloadURL();
    } catch (_) {
      // Primera vez: subir desde assets
      print('📤 Subiendo imagen por defecto a Firebase Storage...');
      final byteData = await rootBundle.load('assets/images/icono.jpg');
      final bytes = byteData.buffer.asUint8List();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      print('✅ Imagen por defecto subida: $url');
      return url;
    }
  }

  Future<List<String>> _uploadPhotos() async {
    if (_images.isEmpty) {
      print('📷 Sin fotos – usando imagen por defecto...');
      final defaultUrl = await _getOrUploadDefaultPhoto();
      return [defaultUrl];
    }

    final List<String> photoUrls = [];

    print('📤 Subiendo ${_images.length} fotos comprimidas a Firebase...');

    for (var i = 0; i < _images.length; i++) {
      try {
        final image = _images[i];
        print('   📸 Subiendo foto ${i + 1}/${_images.length}...');

        final fileName = 'spots/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        await ref.putFile(image);
        final url = await ref.getDownloadURL();
        photoUrls.add(url);

        print('   ✅ Foto ${i + 1} subida correctamente');
      } catch (e) {
        print('   ❌ Error subiendo foto ${i + 1}: $e');
      }
    }

    print('✅ Todas las fotos subidas (${photoUrls.length}/${_images.length})');
    return photoUrls;
  }

  Future<void> _createSpot() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      print('📸 Subiendo fotos...');
      final photoUrls = await _uploadPhotos();
      print('✅ Fotos subidas: ${photoUrls.length}');

      final firestoreService = ref.read(firestoreServiceProvider);

      if (_sendToModeration) {
        print('⏳ Creando spot pendiente de moderación...');

        final pendingSpot = PendingSpot(
          id: '',
          name: _nameController.text.trim(),
          description: _detailsController.text.trim(),
          access: _accessController.text.trim(),
          safety: _safetyController.text.trim(),
          category: _selectedCategory.name,
          latitude: _latitude!,
          longitude: _longitude!,
          photoUrls: photoUrls,
          createdBy: currentUser.uid,
          createdAt: DateTime.now(),
        );

        print('💾 Guardando en Firestore...');
        await firestoreService.createPendingSpot(pendingSpot);
        print('✅ Spot pendiente creado exitosamente');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.spotPendingNotice),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        print('✅ Creando spot directamente...');

        final spot = SpotModel(
          id: '',
          name: _nameController.text.trim(),
          details: _detailsController.text.trim(),
          access: _accessController.text.trim(),
          safety: _safetyController.text.trim(),
          category: _selectedCategory,
          latitude: _latitude!,
          longitude: _longitude!,
          photoUrls: photoUrls,
          createdBy: currentUser.uid,
          createdAt: DateTime.now(),
        );

        print('💾 Guardando en Firestore...');
        await firestoreService.createSpot(spot);
        print('✅ Spot creado exitosamente');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.spotCreatedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e, stackTrace) {
      print('❌ ERROR al crear spot: $e');
      print('📍 StackTrace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.createSpotError}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
        _sendToModeration = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createSpotTitle),
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
              onPressed: _validateAndCreateSpot,
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
              _buildLocationSection(l10n),
              const SizedBox(height: 20),
              _buildCategorySelector(l10n),
              const SizedBox(height: 20),
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
          return l10n.detailsRequired;
        }
        if (value.trim().length < 10) {
          return l10n.describeBetter;
        }
        return null;
      }
          : null,
    );
  }

  Widget _buildLocationSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  l10n.locationLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TypeAheadField<LocationSuggestion>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: l10n.searchPlaceHint,
                  hintText: l10n.searchPlaceExample,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _locationController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _locationController.clear();
                        _latitude = null;
                        _longitude = null;
                        _selectedAddress = null;
                      });
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              suggestionsCallback: (pattern) async {
                if (pattern.length < 3) return [];
                final nominatim = NominatimService();
                return await nominatim.searchLocation(pattern);
              },

              itemBuilder: (context, LocationSuggestion suggestion) {
                IconData icon;
                switch (suggestion.type) {
                  case 'city':
                  case 'town':
                  case 'village':
                    icon = Icons.location_city;
                    break;
                  case 'road':
                  case 'street':
                    icon = Icons.route;
                    break;
                  default:
                    icon = Icons.place;
                }

                return ListTile(
                  leading: Icon(icon, color: Colors.blue),
                  title: Text(
                    suggestion.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${suggestion.latitude.toStringAsFixed(4)}, ${suggestion.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                );
              },

              onSuggestionSelected: (LocationSuggestion suggestion) {
                setState(() {
                  _latitude = suggestion.latitude;
                  _longitude = suggestion.longitude;
                  _selectedAddress = suggestion.displayName;
                  _locationController.text = suggestion.displayName;
                });
              },

              noItemsFoundBuilder: (context) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.noResultsFound,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),

              loadingBuilder: (context) => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _selectLocationOnMap,
              icon: const Icon(Icons.map),
              label: Text(l10n.selectOnMap),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoadingLocation)
              const Center(child: CircularProgressIndicator())
            else if (_latitude != null && _longitude != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.locationSelected,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_selectedAddress != null)
                      Text(
                        _selectedAddress!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    Text(
                      'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else
              TextButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: Text(l10n.useCurrentLocation),
              ),
          ],
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.photosCountLabel(_images.length),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.photosOptionalHint,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (_images.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _images[index],
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
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.galleryMultiple),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
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