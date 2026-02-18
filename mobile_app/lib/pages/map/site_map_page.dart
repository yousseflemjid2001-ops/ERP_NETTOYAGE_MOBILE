import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/theme.dart';

/// SiteMapPage — affiche la carte Google Maps avec :
///  - la position du site (marker bleu)
///  - la position du check-in agent (marker vert)
///  - la position du check-out agent (marker rouge)
///  - un cercle de 200m autour du site (zone acceptable)

class SiteMapPage extends StatefulWidget {
  final String siteName;
  final String? siteAddress;
  final double siteLat;
  final double siteLng;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;

  const SiteMapPage({
    super.key,
    required this.siteName,
    this.siteAddress,
    required this.siteLat,
    required this.siteLng,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
  });

  @override
  State<SiteMapPage> createState() => _SiteMapPageState();
}

class _SiteMapPageState extends State<SiteMapPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _buildMarkersAndCircles();
  }

  void _buildMarkersAndCircles() {
    // Marker site
    _markers.add(
      Marker(
        markerId: const MarkerId('site'),
        position: LatLng(widget.siteLat, widget.siteLng),
        infoWindow: InfoWindow(
          title: widget.siteName,
          snippet: widget.siteAddress ?? 'Site d\'intervention',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Cercle rayon acceptable autour du site
    _circles.add(
      Circle(
        circleId: const CircleId('site_radius'),
        center: LatLng(widget.siteLat, widget.siteLng),
        radius: 200,
        fillColor: AppTheme.primaryColor.withOpacity(0.1),
        strokeColor: AppTheme.primaryColor.withOpacity(0.5),
        strokeWidth: 2,
      ),
    );

    // Marker check-in
    if (widget.checkInLat != null && widget.checkInLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('checkin'),
          position: LatLng(widget.checkInLat!, widget.checkInLng!),
          infoWindow: const InfoWindow(
            title: 'Check-in',
            snippet: 'Position d\'arrivée enregistrée',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    // Marker check-out
    if (widget.checkOutLat != null && widget.checkOutLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('checkout'),
          position: LatLng(widget.checkOutLat!, widget.checkOutLng!),
          infoWindow: const InfoWindow(
            title: 'Check-out',
            snippet: 'Position de sortie enregistrée',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  CameraPosition get _initialCamera {
    return CameraPosition(
      target: LatLng(widget.siteLat, widget.siteLng),
      zoom: 15.5,
    );
  }

  void _fitAllMarkers() {
    if (_mapController == null) return;
    if (_markers.isEmpty) return;

    double minLat = widget.siteLat;
    double maxLat = widget.siteLat;
    double minLng = widget.siteLng;
    double maxLng = widget.siteLng;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.001, minLng - 0.001),
          northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
        ),
        60.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.siteName),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded),
            tooltip: 'Ajuster la vue',
            onPressed: _fitAllMarkers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Légende
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendItem(color: AppTheme.primaryColor, label: 'Site'),
                if (widget.checkInLat != null)
                  _LegendItem(
                    color: AppTheme.secondaryColor,
                    label: 'Check-in',
                  ),
                if (widget.checkOutLat != null)
                  _LegendItem(color: AppTheme.errorColor, label: 'Check-out'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Carte
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: _initialCamera,
              markers: _markers,
              circles: _circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapToolbarEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
          // Info site
          if (widget.siteAddress != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.siteAddress!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
