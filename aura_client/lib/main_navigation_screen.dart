import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibration/vibration.dart';
import 'red_alert_screen.dart';
import 'flash_flood_warning_screen.dart';
import 'alert_list_screen.dart';
import 'guide_screen.dart';
import 'settings_screen.dart';
import 'api_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final ApiService _api;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    _screens = [
      MapDashboardScreen(api: _api),
      AlertListScreen(isEmbedded: true, api: _api),
      GuideScreen(api: _api, isEmbedded: true),
      SettingsScreen(isEmbedded: true, api: _api),
    ];
  }

  @override
  void dispose() {
    _api.disconnect();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B2333),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1B2333),
          selectedItemColor: const Color(0xFFE94B4B),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Safety',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  MAP DASHBOARD (OpenStreetMap via flutter_map)
// ================================================================

class MapDashboardScreen extends StatefulWidget {
  final ApiService api;
  const MapDashboardScreen({super.key, required this.api});

  @override
  State<MapDashboardScreen> createState() => _MapDashboardScreenState();
}

class _MapDashboardScreenState extends State<MapDashboardScreen> {
  // Alert state
  bool _isFireDetected = false;
  bool _isFloodDetected = false;
  String _currentThreatLevel = 'safe';
  String _alertTitle = '';
  String _alertMessage = '';
  bool _hasPushedAlert = false;

  StreamSubscription? _wsSub;
  final MapController _mapController = MapController();

  // Sensor positions from backend
  List<Map<String, dynamic>> _positions = [];

  // Latest sensor values
  final Map<String, Map<String, dynamic>> _latestValues = {};

  // Evacuation route data
  Map<String, dynamic>? _evacuationRoute;

  // Default center
  static const LatLng _defaultCenter = LatLng(11.6854, 76.1320);

  @override
  void initState() {
    super.initState();

    // Connect WebSocket
    widget.api.connectWebSocket();
    _wsSub = widget.api.sensorStream.listen(_onSensorData);

    // Load sensor positions
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    final pos = await widget.api.fetchPositions();
    if (mounted && pos.isNotEmpty) {
      setState(() => _positions = pos);
    }
  }

  void _onSensorData(Map<String, dynamic> data) {
    if (!mounted) return;

    final sensor = data['sensor'] as String? ?? '';
    final threatLevel = data['threat_level'] as String? ?? 'safe';
    final alert = data['alert'] as Map<String, dynamic>?;

    _latestValues[sensor] = data;

    setState(() {
      _currentThreatLevel = threatLevel;

      if (threatLevel == 'critical') {
        // Trigger vibration on critical threats
        Vibration.hasVibrator().then((has) {
          if (has == true) {
            Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
          }
        });

        if (sensor == 'gas-leakage' || sensor == 'temperature' || sensor == 'camera') {
          _isFireDetected = true;
          _isFloodDetected = false;
          _alertTitle = alert?['title'] ?? 'HAZARD ALERT';
          _alertMessage = alert?['message'] ?? 'Critical sensor threshold exceeded.';

          if (!_hasPushedAlert) {
            _hasPushedAlert = true;
            _fetchEvacuationRoute(sensor);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    RedAlertScreen(location: _getLocationForSensor(sensor), alert: alert),
              ),
            ).then((_) {
              _hasPushedAlert = false;
            });
          }
        } else if (sensor == 'ultra-sonic' || sensor == 'humidity') {
          _isFloodDetected = true;
          _isFireDetected = false;
          _alertTitle = alert?['title'] ?? 'FLOOD WARNING';
          _alertMessage = alert?['message'] ?? 'Critical water level detected.';

          if (!_hasPushedAlert) {
            _hasPushedAlert = true;
            _fetchEvacuationRoute(sensor);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FlashFloodWarningScreen(
                  location: _getLocationForSensor(sensor),
                  alert: alert,
                ),
              ),
            ).then((_) {
              _hasPushedAlert = false;
            });
          }
        }
      } else if (threatLevel == 'warning') {
        _alertTitle = alert?['title'] ?? 'Warning';
        _alertMessage = alert?['message'] ?? 'Sensor value in warning range.';
        // Clear critical states and evacuation route on downgrade
        if (sensor == 'gas-leakage' || sensor == 'temperature' || sensor == 'camera') {
          _isFireDetected = false;
        }
        if (sensor == 'ultra-sonic' || sensor == 'humidity') {
          _isFloodDetected = false;
        }
        _evacuationRoute = null;
      } else {
        // Safe — clear everything for this sensor category
        if (sensor == 'gas-leakage' || sensor == 'temperature' || sensor == 'camera') {
          _isFireDetected = false;
        }
        if (sensor == 'ultra-sonic' || sensor == 'humidity') {
          _isFloodDetected = false;
        }
        _evacuationRoute = null;
        _alertTitle = '';
        _alertMessage = '';
      }
    });
  }

  String _getLocationForSensor(String sensorType) {
    final pos = _positions.where((p) => p['sensor_type'] == sensorType);
    if (pos.isNotEmpty) {
      return pos.first['name'] ?? 'Sensor Location';
    }
    return 'Unknown Location';
  }

  Future<void> _fetchEvacuationRoute(String sensorType) async {
    final pos = _positions.where((p) => p['sensor_type'] == sensorType);
    if (pos.isEmpty) return;

    final dangerLat = (pos.first['lat'] as num).toDouble();
    final dangerLng = (pos.first['lng'] as num).toDouble();

    final route = await widget.api.fetchEvacuationRoute(dangerLat, dangerLng);
    if (route == null || !mounted) return;

    setState(() {
      _evacuationRoute = route;
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  // Per-sensor status calculation (mirrors web dashboard getStatus)
  String _calculateStatus(String type, double value) {
    if (type == 'temperature') {
      if (value <= 30) return 'normal';
      if (value <= 45) return 'warning';
      return 'alert';
    }
    if (type == 'humidity') {
      if (value <= 60) return 'normal';
      if (value <= 85) return 'warning';
      return 'alert';
    }
    if (type == 'gas-leakage') {
      if (value <= 800) return 'normal';
      if (value <= 1200) return 'warning';
      return 'alert';
    }
    if (type == 'ultra-sonic' || type == 'ultrasonic') {
      if (value < 25) return 'alert';
      if (value < 50) return 'warning';
      return 'normal';
    }
    if (type == 'camera') {
      if (value > 6000) return 'alert';
      if (value > 2000) return 'warning';
      return 'normal';
    }
    return 'normal';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'alert': return const Color(0xFFf85149);
      case 'warning': return const Color(0xFFd29922);
      default: return const Color(0xFF3fb950);
    }
  }

  static const Map<String, String> _sensorUnits = {
    'temperature': '°C',
    'humidity': '%',
    'gas-leakage': 'ppm',
    'ultra-sonic': 'cm',
    'camera': '',
  };

  // Build marker list — each marker colored by its own sensor value
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final p in _positions) {
      final lat = (p['lat'] as num).toDouble();
      final lng = (p['lng'] as num).toDouble();
      final type = p['sensor_type'] as String? ?? '';
      final name = p['name'] as String? ?? 'Sensor';
      final lv = _latestValues[type];
      final rawVal = lv?['value'] as num?;
      final status = rawVal != null
          ? _calculateStatus(type, rawVal.toDouble())
          : 'normal';
      final color = _getStatusColor(status);
      final valueStr = rawVal != null
          ? '${rawVal}${_sensorUnits[type] ?? ''}'
          : 'No data';

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showSensorInfo(name, type, valueStr),
            child: Icon(_getSensorIcon(type), color: color, size: 32),
          ),
        ),
      );
    }

    // Evacuation route markers
    if (_evacuationRoute != null) {
      // Safe exit marker
      if (_evacuationRoute!['safe_exit'] != null) {
        final exitPt = _evacuationRoute!['safe_exit'];
        final exitLat = (exitPt['lat'] as num).toDouble();
        final exitLng = (exitPt['lng'] as num).toDouble();
        final dist = exitPt['distance_m'] ?? '?';
        final time = exitPt['estimated_time_min'] ?? '?';

        markers.add(
          Marker(
            point: LatLng(exitLat, exitLng),
            width: 180,
            height: 34,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3fb950),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
              ),
              child: Text(
                'SAFE EXIT (${dist}m / ${time} min)',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      // User location marker
      if (_evacuationRoute!['user_location'] != null) {
        final userPt = _evacuationRoute!['user_location'];
        markers.add(
          Marker(
            point: LatLng((userPt['lat'] as num).toDouble(), (userPt['lng'] as num).toDouble()),
            width: 36,
            height: 36,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF388bfd),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
              ),
              child: const Center(
                child: Text('YOU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      }

      // Blocked route X marker (midpoint of blocked route)
      if (_evacuationRoute!['blocked_route'] != null) {
        final blocked = _evacuationRoute!['blocked_route'] as List;
        if (blocked.length > 1) {
          final mid = blocked[1];
          markers.add(
            Marker(
              point: LatLng((mid[0] as num).toDouble(), (mid[1] as num).toDouble()),
              width: 28,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFf85149),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
                ),
                child: const Center(
                  child: Text('X', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          );
        }
      }
    }

    return markers;
  }

  IconData _getSensorIcon(String type) {
    switch (type) {
      case 'gas-leakage':
        return Icons.local_fire_department;
      case 'ultra-sonic':
        return Icons.water;
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      default:
        return Icons.sensors;
    }
  }

  void _showSensorInfo(String name, String type, String value) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B2333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type: $type',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Value: $value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Build danger zone circles — per-sensor, matching web dashboard colors
  List<CircleMarker> _buildCircles() {
    final circles = <CircleMarker>[];

    // Web dashboard zone colors per sensor type
    const zoneColors = {
      'gas-leakage':  {'critical': Color(0xFFf85149), 'warning': Color(0xFFd29922)},
      'ultra-sonic':  {'critical': Color(0xFF388bfd), 'warning': Color(0xFF58a6ff)},
      'temperature':  {'critical': Color(0xFFf88800), 'warning': Color(0xFFd29922)},
      'humidity':     {'critical': Color(0xFF58a6ff), 'warning': Color(0xFF388bfd)},
      'camera':       {'critical': Color(0xFFf85149), 'warning': Color(0xFFd29922)},
    };

    for (final p in _positions) {
      final type = p['sensor_type'] as String? ?? '';
      final lat = (p['lat'] as num).toDouble();
      final lng = (p['lng'] as num).toDouble();

      final lv = _latestValues[type];
      final rawVal = lv?['value'] as num?;
      if (rawVal == null) continue;

      final status = _calculateStatus(type, rawVal.toDouble());
      if (status == 'normal') continue;

      final colors = zoneColors[type] ?? {'critical': const Color(0xFFf85149), 'warning': const Color(0xFFd29922)};
      final isAlert = status == 'alert';
      final zoneColor = isAlert ? colors['critical']! : colors['warning']!;
      final radius = isAlert ? 200.0 : 120.0;
      final opacity = isAlert ? 0.25 : 0.15;

      circles.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: radius,
          useRadiusInMeter: true,
          color: zoneColor.withValues(alpha: opacity),
          borderColor: zoneColor,
          borderStrokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  // Build evacuation route polylines
  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    if (_evacuationRoute != null) {
      // Safe route (green)
      final safeRoute = (_evacuationRoute!['safe_route'] as List)
          .map(
            (pt) =>
                LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()),
          )
          .toList();

      polylines.add(
        Polyline(points: safeRoute, color: Colors.green, strokeWidth: 5),
      );

      // Blocked route (red dashed)
      final blockedRoute = (_evacuationRoute!['blocked_route'] as List)
          .map(
            (pt) =>
                LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()),
          )
          .toList();

      polylines.add(
        Polyline(points: blockedRoute, color: Colors.red, strokeWidth: 4),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    bool hasActiveAlert = _isFireDetected || _isFloodDetected;
    final center = _positions.isNotEmpty
        ? LatLng(
            (_positions.first['lat'] as num).toDouble(),
            (_positions.first['lng'] as num).toDouble(),
          )
        : _defaultCenter;

    return Scaffold(
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 14.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.aura_client',
              ),
              CircleLayer(circles: _buildCircles()),
              PolylineLayer(polylines: _buildPolylines()),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Top alert banner — shows for warning AND critical
          if (hasActiveAlert || _alertTitle.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _isFireDetected
                      ? Colors.red.shade900
                      : _isFloodDetected
                          ? Colors.blue.shade900
                          : Colors.orange.shade900,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_isFireDetected
                              ? Colors.red
                              : _isFloodDetected
                                  ? Colors.blue
                                  : Colors.orange)
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFireDetected
                          ? Icons.local_fire_department
                          : _isFloodDetected
                              ? Icons.flood
                              : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _alertTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _alertMessage,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Sensor data cards at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2333),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      _sensorCard('Temp', 'temperature', Icons.thermostat, 'C'),
                      const SizedBox(width: 8),
                      _sensorCard(
                        'Humidity',
                        'humidity',
                        Icons.water_drop,
                        '%',
                      ),
                      const SizedBox(width: 8),
                      _sensorCard(
                        'Gas',
                        'gas-leakage',
                        Icons.local_fire_department,
                        'ppm',
                      ),
                      const SizedBox(width: 8),
                      _sensorCard('Water', 'ultra-sonic', Icons.water, 'cm'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorCard(
    String label,
    String sensorType,
    IconData icon,
    String unit,
  ) {
    final lv = _latestValues[sensorType];
    final rawVal = lv?['value'] as num?;
    final value = rawVal != null ? rawVal.toStringAsFixed(0) : '--';
    final status = rawVal != null
        ? _calculateStatus(sensorType, rawVal.toDouble())
        : 'normal';
    final cardColor = _getStatusColor(status);
    final statusLabel = status.toUpperCase();

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: cardColor, size: 20),
            const SizedBox(height: 4),
            Text(
              '$value$unit',
              style: TextStyle(
                color: cardColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              statusLabel,
              style: TextStyle(
                color: cardColor,
                fontWeight: FontWeight.w700,
                fontSize: 8,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
