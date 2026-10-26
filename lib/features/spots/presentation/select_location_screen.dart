// lib/features/spots/presentation/select_location_screen.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SelectLocationScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const SelectLocationScreen({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
  }) : super(key: key);

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  CircleAnnotation? _pinCircle;

  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _address;
  bool _isLoadingAddress = false;

  // 🆕 Indica si tenemos una ubicación real del usuario
  bool get _hasUserLocation =>
      widget.initialLatitude != null && widget.initialLongitude != null;

  @override
  void initState() {
    super.initState();
    // Solo asignamos si hay ubicación real, si no dejamos null
    // para que el mapa arranque en posición neutra y luego
    // el usuario toque donde quiera
    if (_hasUserLocation) {
      _selectedLatitude = widget.initialLatitude;
      _selectedLongitude = widget.initialLongitude;
      _loadAddress();
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    _mapboxMap?.annotations.createCircleAnnotationManager().then((manager) {
      _circleAnnotationManager = manager;

      // 🆕 Solo añadimos pin y centramos si hay ubicación real
      if (_hasUserLocation) {
        _addPinMarker(_selectedLatitude!, _selectedLongitude!);
        // Mover la cámara programáticamente a la ubicación del usuario
        _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(_selectedLongitude!, _selectedLatitude!),
            ),
            zoom: 15.0,
          ),
          MapAnimationOptions(duration: 800),
        );
      }
    });

    _mapboxMap?.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));
  }

  Future<void> _addPinMarker(double lat, double lng) async {
    if (_circleAnnotationManager == null) return;

    if (_pinCircle != null) {
      await _circleAnnotationManager?.delete(_pinCircle!);
    }

    final point = Point(coordinates: Position(lng, lat));

    _pinCircle = await _circleAnnotationManager?.create(
      CircleAnnotationOptions(
        geometry: point,
        circleRadius: 15.0,
        circleColor: Colors.red.value,
        circleStrokeWidth: 4.0,
        circleStrokeColor: Colors.white.value,
        circleOpacity: 0.9,
      ),
    );
  }

  void _onMapTap(MapContentGestureContext context) {
    if (_mapboxMap == null) return;
    _updateMarkerPosition(
      context.point.coordinates.lat.toDouble(),
      context.point.coordinates.lng.toDouble(),
    );
  }

  void _updateMarkerPosition(double lat, double lng) {
    setState(() {
      _selectedLatitude = lat;
      _selectedLongitude = lng;
    });
    _addPinMarker(lat, lng);
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    if (_selectedLatitude == null || _selectedLongitude == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedLatitude!,
        _selectedLongitude!,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _address =
              '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
        });
      }
    } catch (e) {
      print('Error obteniendo dirección: $e');
      setState(() {
        _address = l10n?.addressNotAvailable ?? 'Dirección no disponible';
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  void _confirmLocation() {
    if (_selectedLatitude == null || _selectedLongitude == null) return;
    Navigator.pop(context, {
      'latitude': _selectedLatitude,
      'longitude': _selectedLongitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLocation),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            // 🆕 Solo habilitado si hay ubicación seleccionada
            onPressed: _selectedLatitude != null ? _confirmLocation : null,
            tooltip: l10n.confirmLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            onTapListener: (context) {
              _onMapTap(context);
            },
            // 🆕 cameraOptions arranca en posición neutra (mundo)
            // La cámara se mueve a la ubicación del usuario en _onMapCreated
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  widget.initialLongitude ?? 0.0,
                  widget.initialLatitude ?? 20.0,
                ),
              ),
              zoom: _hasUserLocation ? 15.0 : 2.0,
            ),
            styleUri: MapboxStyles.OUTDOORS,
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.touch_app,
                          color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.tapMapInstruction,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_selectedLatitude != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.locationSelected,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingAddress)
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.gettingAddress),
                          ],
                        )
                      else if (_address != null)
                        Row(
                          children: [
                            const Icon(Icons.place,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _address!,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Lat: ${_selectedLatitude?.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Container(
                                width: 1,
                                height: 12,
                                color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lng: ${_selectedLongitude?.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _selectedLatitude != null ? _confirmLocation : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle),
                    const SizedBox(width: 8),
                    Text(l10n.confirmLocationButton),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}