import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'red_alert_screen.dart';
import 'flash_flood_warning_screen.dart';
import 'alert_list_screen.dart';
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
      const Scaffold(
        body: Center(
          child: Text(
            "Guide Content (Coming Soon)",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
      const SettingsScreen(isEmbedded: true),
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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
                label: 'Map'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                activeIcon: Icon(Icons.notifications),
                label: 'Alerts'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: 'Safety'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile'),
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
        if (sensor == 'gas-leakage' || sensor == 'temperature') {
          _isFireDetected = true;
          _isFloodDetected = false;
          _alertTitle = alert?['title'] ?? 'Hazard Alert';
          _alertMessage = alert?['message'] ?? '';

          if (!_hasPushedAlert) {
            _hasPushedAlert = true;
            _fetchEvacuationRoute(sensor);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    RedAlertScreen(location: _getLocationForSensor(sensor)),
              ),
            ).then((_) {
              _hasPushedAlert = false;
            });
          }
        } else if (sensor == 'ultrasonic' || sensor == 'humidity') {
          _isFloodDetected = true;
          _isFireDetected = false;
          _alertTitle = alert?['title'] ?? 'Flood Warning';
          _alertMessage = alert?['message'] ?? '';

          if (!_hasPushedAlert) {
            _hasPushedAlert = true;
            _fetchEvacuationRoute(sensor);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FlashFloodWarningScreen(
                  location: _getLocationForSensor(sensor),
                ),
              ),
            ).then((_) {
              _hasPushedAlert = false;
            });
          }
        }
      } else if (threatLevel == 'warning') {
        _alertTitle = alert?['title'] ?? 'Warning';
        _alertMessage = alert?['message'] ?? '';
        // Clear critical-only state (red zone + evacuation)
        if (sensor == 'gas-leakage' || sensor == 'temperature') {
          _isFireDetected = false;
        }
        if (sensor == 'ultrasonic' || sensor == 'humidity') {
          _isFloodDetected = false;
        }
        _evacuationRoute = null;
      } else {
        if (sensor == 'gas-leakage' || sensor == 'temperature') {
          _isFireDetected = false;
        }
        if (sensor == 'ultrasonic' || sensor == 'humidity') {
          _isFloodDetected = false;
        }
        _evacuationRoute = null;
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

  // Build marker list
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final p in _positions) {
      final lat = (p['lat'] as num).toDouble();
      final lng = (p['lng'] as num).toDouble();
      final type = p['sensor_type'] as String? ?? '';
      final name = p['name'] as String? ?? 'Sensor';
      final lv = _latestValues[type];
      final value = lv != null ? '${lv['value']}' : 'No data';

      bool isThreat = (type == 'gas-leakage' || type == 'temperature') &&
              _isFireDetected ||
          (type == 'ultrasonic' || type == 'humidity') && _isFloodDetected;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            _showSensorInfo(name, type, value);
          },
          child: Icon(
            _getSensorIcon(type),
            color: isThreat ? Colors.red : const Color(0xFF3fb950),
            size: 32,
          ),
        ),
      ));
    }

    // Safe exit marker from evacuation route
    if (_evacuationRoute != null) {
      final exitPt = _evacuationRoute!['safe_exit'];
      final exitLat = (exitPt['lat'] as num).toDouble();
      final exitLng = (exitPt['lng'] as num).toDouble();

      markers.add(Marker(
        point: LatLng(exitLat, exitLng),
        width: 150,
        height: 40,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            'SAFE EXIT ${exitPt['distance_m']}m',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ));
    }

    return markers;
  }

  IconData _getSensorIcon(String type) {
    switch (type) {
      case 'gas-leakage':
        return Icons.local_fire_department;
      case 'ultrasonic':
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
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Type: $type',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 4),
            Text('Value: $value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Build danger zone circles based on per-sensor threat level
  List<CircleMarker> _buildCircles() {
    final circles = <CircleMarker>[];

    for (final p in _positions) {
      final type = p['sensor_type'] as String? ?? '';
      final lat = (p['lat'] as num).toDouble();
      final lng = (p['lng'] as num).toDouble();

      // Get this sensor's threat level
      final lv = _latestValues[type];
      final threat = lv?['threat_level'] ?? 'safe';
      if (threat == 'safe') continue; // no zone for safe

      Color zoneColor;
      double radius;
      double opacity;

      if (threat == 'critical') {
        // Red zone for gas/temp, blue zone for water/humidity
        zoneColor = (type == 'gas-leakage' || type == 'temperature')
            ? Colors.red
            : Colors.blue;
        radius = 500;
        opacity = 0.25;
      } else {
        // Yellow zone for gas/temp warning, light blue for water/humidity warning
        zoneColor = (type == 'gas-leakage' || type == 'temperature')
            ? Colors.orange
            : Colors.lightBlue;
        radius = 300;
        opacity = 0.15;
      }

      circles.add(CircleMarker(
        point: LatLng(lat, lng),
        radius: radius,
        useRadiusInMeter: true,
        color: zoneColor.withValues(alpha: opacity),
        borderColor: zoneColor,
        borderStrokeWidth: 2,
      ));
    }

    return circles;
  }

  // Build evacuation route polylines
  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    if (_evacuationRoute != null) {
      // Safe route (green)
      final safeRoute = (_evacuationRoute!['safe_route'] as List)
          .map((pt) =>
              LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()))
          .toList();

      polylines.add(Polyline(
        points: safeRoute,
        color: Colors.green,
        strokeWidth: 5,
      ));

      // Blocked route (red dashed)
      final blockedRoute = (_evacuationRoute!['blocked_route'] as List)
          .map((pt) =>
              LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()))
          .toList();

      polylines.add(Polyline(
        points: blockedRoute,
        color: Colors.red,
        strokeWidth: 4,
      ));
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
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.aura_client',
              ),
              CircleLayer(circles: _buildCircles()),
              PolylineLayer(polylines: _buildPolylines()),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Top alert banner
          if (hasActiveAlert)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isFireDetected
                      ? Colors.red.shade900
                      : Colors.blue.shade900,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_isFireDetected ? Colors.red : Colors.blue)
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
                          : Icons.flood,
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
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
                      _sensorCard(
                          'Temp', 'temperature', Icons.thermostat, 'C'),
                      const SizedBox(width: 8),
                      _sensorCard(
                          'Humidity', 'humidity', Icons.water_drop, '%'),
                      const SizedBox(width: 8),
                      _sensorCard('Gas', 'gas-leakage',
                          Icons.local_fire_department, 'ppm'),
                      const SizedBox(width: 8),
                      _sensorCard(
                          'Water', 'ultrasonic', Icons.water, 'cm'),
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
      String label, String sensorType, IconData icon, String unit) {
    final lv = _latestValues[sensorType];
    final value = lv != null ? (lv['value'] as num).toStringAsFixed(0) : '--';
    final threatLevel = lv?['threat_level'] ?? 'safe';

    Color cardColor;
    if (threatLevel == 'critical') {
      cardColor = Colors.red;
    } else if (threatLevel == 'warning') {
      cardColor = Colors.orange;
    } else {
      cardColor = const Color(0xFF3fb950);
    }

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
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
