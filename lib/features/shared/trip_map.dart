import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';

/// OpenStreetMap view of a vehicle's last position (no API key needed).
class TripMap extends StatelessWidget {
  const TripMap({super.key, required this.points, this.height = 220});

  /// Label -> position. The first point centres the map.
  final Map<String, LatLng> points;
  final double height;

  static const gaborone = LatLng(-24.6282, 25.9231);

  @override
  Widget build(BuildContext context) {
    final center = points.isEmpty ? gaborone : points.values.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: points.isEmpty ? 11 : 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gimble.schooldrop',
            ),
            MarkerLayer(markers: [
              for (final entry in points.entries)
                Marker(
                  point: entry.value,
                  width: 140,
                  height: 56,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.navy, borderRadius: BorderRadius.circular(6)),
                      child: Text(entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const Icon(Icons.directions_bus, color: AppTheme.amber, size: 30),
                  ]),
                ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
          ],
        ),
      ),
    );
  }
}
