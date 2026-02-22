import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'red_alert_screen.dart';
import 'alert_list_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // We keep track of the screens so they don't rebuild from scratch every tab switch
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const MapDashboardScreen(), // 0: Map
      const AlertListScreen(
        isEmbedded: true,
      ), // 1: Alerts (We'll adapt it to not push full-screen)
      const Scaffold(
        body: Center(
          child: Text(
            "Guide Content (Coming Soon)",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ), // 2: Safety/Guide
      const SettingsScreen(isEmbedded: true), // 3: Profile (We'll adapt it too)
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFD32F2F),
          unselectedItemColor: Colors.grey.shade400,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Guide',
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

class MapDashboardScreen extends StatefulWidget {
  const MapDashboardScreen({super.key});

  @override
  State<MapDashboardScreen> createState() => _MapDashboardScreenState();
}

class _MapDashboardScreenState extends State<MapDashboardScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Fake stream controller to simulate firebase for the UI layout requests.
  final StreamController<String> _mockStreamController =
      StreamController<String>.broadcast();

  bool _isFireDetected = false;
  bool _hasPushedAlert = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const LatLng _box1Location = LatLng(11.6854, 76.1320);
  static const LatLng _userLocation = LatLng(11.6800, 76.1300);
  static const LatLng _safeExit = LatLng(11.6700, 76.1200);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween(begin: 0.1, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mockStreamController.stream.listen((status) {
      _handleStatusUpdate(status);
    });
  }

  void _handleStatusUpdate(String status) {
    if (!mounted) return;

    if (status == "FIRE_DETECTED") {
      setState(() {
        _isFireDetected = true;
      });

      if (!_hasPushedAlert) {
        _hasPushedAlert = true;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const RedAlertScreen(location: "ZONE ALPHA (BOX 1)"),
          ),
        ).then((_) {
          _hasPushedAlert = false;
        });
      }
    } else {
      setState(() {
        _isFireDetected = false;
      });
    }
  }

  void _simulateFire() {
    _mockStreamController.add("FIRE_DETECTED");
  }

  void _simulateSafe() {
    _mockStreamController.add("SAFE");
  }

  @override
  void dispose() {
    _mockStreamController.close();
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.aura_client',
              ),
              PolylineLayer(
                polylines: [
                  if (!_isFireDetected)
                    Polyline(
                      points: const [_userLocation, _box1Location, _safeExit],
                      color: Colors.blue,
                      strokeWidth: 5,
                    )
                  else ...[
                    Polyline(
                      points: const [_userLocation, _box1Location, _safeExit],
                      color: Colors.red.withOpacity(0.5),
                      strokeWidth: 3,
                    ),
                    Polyline(
                      points: const [
                        _userLocation,
                        LatLng(11.6750, 76.1400),
                        _safeExit,
                      ],
                      color: Colors.green,
                      strokeWidth: 6,
                    ),
                  ],
                ],
              ),
              if (_isFireDetected)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _box1Location,
                      radius: 500,
                      useRadiusInMeter: true,
                      color: Colors.red.withOpacity(0.2),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                    ),
                    CircleMarker(
                      point: _box1Location,
                      radius: 500,
                      useRadiusInMeter: true,
                      color: Colors.red.withOpacity(_pulseAnimation.value),
                      borderColor: Colors.transparent,
                      borderStrokeWidth: 0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation,
                    width: 80,
                    height: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 40,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Marker(
                    point: _box1Location,
                    width: 60,
                    height: 60,
                    child: Icon(
                      Icons.location_on,
                      color: _isFireDetected ? Colors.red : Colors.green,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _isFireDetected
                              ? Colors.red.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isFireDetected ? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isFireDetected ? 'CRITICAL ALERT' : 'SYSTEM SAFE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: _isFireDetected ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.notifications_none,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const CircleAvatar(
                        backgroundImage: NetworkImage(
                          'https://i.pravatar.cc/150?img=11',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 80, right: 16),
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'sim1',
                      onPressed: _simulateFire,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.fireplace, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'sim2',
                      onPressed: _simulateSafe,
                      backgroundColor: Colors.green,
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 300 * (1 - value)),
                  child: child,
                );
              },
              child: Container(
                height: 300,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CURRENT STATUS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                'Updated live',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _isFireDetected
                                      ? const Color(0xFFD32F2F)
                                      : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _isFireDetected
                                      ? Colors.red
                                      : Colors.black,
                                ),
                                child: Text(
                                  _isFireDetected
                                      ? 'Hazard Detected'
                                      : 'All Clear',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ListView(
                          key: ValueKey<bool>(_isFireDetected),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            if (_isFireDetected)
                              _buildMapAlertCard(
                                icon: Icons.fireplace,
                                iconColor: Colors.red,
                                iconBg: Colors.red.shade50,
                                title: 'Active Fire - Zone Alpha',
                                badgeText: 'CRITICAL',
                                badgeColor: Colors.red,
                                description:
                                    'Sensor network detected fire. Evacuation route recalculated.',
                                time: 'Just now',
                                source: 'Sentinel Node 1',
                              )
                            else ...[
                              _buildMapAlertCard(
                                icon: Icons.check_circle_outline,
                                iconColor: Colors.green,
                                iconBg: Colors.green.shade50,
                                title: 'System Optimal',
                                badgeText: 'STABLE',
                                badgeColor: Colors.green,
                                description:
                                    'All 24 Sentinel Nodes are reporting safe environments.',
                                time: 'Live',
                                source: 'System',
                              ),
                              const SizedBox(height: 16),
                              _buildMapAlertCard(
                                icon: Icons.waves,
                                iconColor: Colors.blue,
                                iconBg: Colors.blue.shade50,
                                title: 'Flash Flood Warning',
                                badgeText: 'ADVISORY',
                                badgeColor: Colors.orange,
                                description:
                                    'Heavy rainfall in nearby district. Monitor status.',
                                time: '1h ago',
                                source: 'IMD Kerala',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapAlertCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required String time,
    required String source,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$time  •  $source',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
