import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import 'trip_map.dart';

/// Tap (or drag the map under the pin) to set a location. Used by SchoolDrop staff to pin schools.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.value, required this.onChanged, this.height = 300});

  final LatLng? value;
  final ValueChanged<LatLng> onChanged;
  final double height;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final pin = widget.value;
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: widget.height,
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: pin ?? TripMap.gaborone,
                initialZoom: pin == null ? 12 : 16,
                onTap: (_, point) => widget.onChanged(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gimble.schooldrop',
                ),
                if (pin != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: pin,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on_rounded, color: AppColors.danger, size: 44),
                    ),
                  ]),
                const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
              ],
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Column(children: [
                _MapButton(icon: Icons.add, onTap: () => _map.move(_map.camera.center, _map.camera.zoom + 1)),
                const SizedBox(height: 6),
                _MapButton(icon: Icons.remove, onTap: () => _map.move(_map.camera.center, _map.camera.zoom - 1)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        pin == null
            ? 'Tap the school\'s gate on the map.'
            : 'Pinned at ${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)} · tap elsewhere to move it',
        style: theme.textTheme.bodySmall?.copyWith(color: pin == null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
      ),
    ]);
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 20, color: Colors.black87)),
        ),
      );
}
