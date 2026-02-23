import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class AlertListScreen extends StatefulWidget {
  final bool isEmbedded;
  final ApiService? api;
  const AlertListScreen({super.key, this.isEmbedded = false, this.api});

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _subscribeToStream();
  }

  Future<void> _loadAlerts() async {
    if (widget.api == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    final alerts = await widget.api!.fetchAllAlerts();
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  void _subscribeToStream() {
    if (widget.api == null) return;
    
    _wsSub = widget.api!.sensorStream.listen((data) {
      if (!mounted) return;
      
      final threatLevel = data['threat_level'] as String? ?? 'safe';
      final alertData = data['alert'] as Map<String, dynamic>?;
      
      if (alertData != null && (threatLevel == 'critical' || threatLevel == 'warning')) {
        setState(() {
          // Add to beginning of the list
          _alerts.insert(0, {
            'id': DateTime.now().millisecondsSinceEpoch,
            'title': alertData['title'] ?? 'New Alert',
            'severity': threatLevel,
            'description': alertData['message'] ?? '',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'sensor_type': data['sensor'] ?? 'unknown',
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await _loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF4C3EE8), // Deep purple
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AURA FEED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4C3EE8),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Resilience Updates',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B2333),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune, color: Color(0xFF1B2333)),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildFilterChip('All Updates', isActive: true),
                  _buildFilterChip(
                    'Critical',
                    icon: Icons.circle,
                    iconColor: Colors.red,
                  ),
                  _buildFilterChip(
                    'Moderate',
                    icon: Icons.circle,
                    iconColor: Colors.orange,
                  ),
                  _buildFilterChip('Monitor'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Alerts List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: const Color(0xFF4C3EE8),
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4C3EE8)))
                  : _alerts.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        children: const [
                          Center(
                            child: Text(
                              'No recent alerts',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          return _buildDynamicFeedCard(alert);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !widget.isEmbedded
          ? BottomNavigationBar(
              currentIndex: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF4C3EE8),
              unselectedItemColor: Colors.grey.shade400,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  label: 'Map',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shield_outlined),
                  label: 'Safety',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildFilterChip(
    String label, {
    bool isActive = false,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1B2333) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade700,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicFeedCard(Map<String, dynamic> alert) {
    final severity = alert['severity']?.toString().toLowerCase() ?? 'info';
    final type = alert['sensor_type']?.toString().toLowerCase() ?? 'unknown';
    
    // Style configurations based on severity
    Color badgeColor = Colors.grey;
    String badgeText = 'Notice';
    if (severity == 'critical') {
      badgeColor = Colors.redAccent;
      badgeText = 'Critical';
    } else if (severity == 'warning') {
      badgeColor = Colors.orange;
      badgeText = 'Warning';
    }

    // Icon associations
    IconData icon = Icons.info_outline;
    if (type.contains('gas') || type.contains('temp')) {
      icon = Icons.local_fire_department_outlined;
    } else if (type.contains('water') || type.contains('ultrasonic') || type.contains('humid')) {
      icon = Icons.water_drop_outlined;
    }

    // Parse timestamp
    String timeStr = '--:--';
    String timeAgoStr = 'Just now';
    if (alert['created_at'] != null) {
      try {
        final dt = DateTime.parse(alert['created_at']).toLocal();
        timeStr = DateFormat.jm().format(dt);
        
        final diff = DateTime.now().difference(dt);
        if (diff.inDays > 0) {
          timeAgoStr = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgoStr = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeAgoStr = '${diff.inMinutes}m ago';
        }
      } catch (_) {}
    }

    return _buildFeedCard(
      icon: icon,
      iconColor: badgeColor,
      badgeText: badgeText,
      badgeColor: badgeColor,
      title: alert['title'] ?? 'Alert',
      location: 'Sensor Network', // Ideally provided by backend mapped data
      description: alert['description'] ?? '',
      time: timeStr,
      timeAgo: timeAgoStr,
      actionText: severity == 'critical' ? 'Evacuate →' : 'Details',
      actionColor: severity == 'critical' ? Colors.redAccent : const Color(0xFF4C3EE8),
    );
  }

  Widget _buildFeedCard({
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String location,
    required String description,
    required String time,
    required String timeAgo,
    required String actionText,
    required Color actionColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
              Text(
                actionText,
                style: TextStyle(
                  color: actionColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
