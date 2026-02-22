import 'package:flutter/material.dart';

class AlertListScreen extends StatelessWidget {
  final bool isEmbedded;
  const AlertListScreen({super.key, this.isEmbedded = false});

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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildSectionDivider('LIVE'),
                  const SizedBox(height: 16),

                  _buildFeedCard(
                    icon: Icons.water_drop_outlined,
                    iconColor: Colors.redAccent,
                    badgeText: 'High Priority',
                    badgeColor: Colors.redAccent,
                    title: 'Flash Flood Warning',
                    location: 'Meppadi Region, Wayanad',
                    description:
                        'Rapid water level rise detected in lower catchment areas. Evacuation protocols...',
                    time: '10:42 AM',
                    timeAgo: '2m ago',
                    actionText: 'Details →',
                    actionColor: const Color(0xFF4C3EE8),
                  ),

                  _buildFeedCard(
                    icon: Icons.local_fire_department_outlined,
                    iconColor: Colors.orange,
                    badgeText: 'Monitor',
                    badgeColor: Colors.orange,
                    title: 'Structural Fire Incident',
                    location: 'Central District, Kochi',
                    description:
                        'Containment operations in progress at commercial complex. Traffic diversion activ...',
                    time: '09:15 AM',
                    timeAgo: '1h ago',
                    actionText: 'Map View 🗺',
                    actionColor: const Color(0xFF4C3EE8),
                  ),

                  _buildFeedCard(
                    icon: Icons.landscape_outlined,
                    iconColor: Colors.grey.shade600,
                    badgeText: 'Advisory',
                    badgeColor: Colors.grey.shade600,
                    title: 'Geological Instability',
                    location: 'High Range, Idukki',
                    description:
                        'Soil saturation levels critical along Munnar...',
                    time: '06:30 AM',
                    timeAgo: '3h ago',
                    actionText: 'Details →',
                    actionColor: const Color(0xFF4C3EE8),
                  ),

                  const SizedBox(height: 16),
                  _buildSectionDivider('ARCHIVED'),
                  const SizedBox(height: 16),

                  // Archived Item
                  Opacity(
                    opacity: 0.6,
                    child: _buildFeedCard(
                      icon: Icons.cloud_off_outlined,
                      iconColor: Colors.grey,
                      badgeText: 'Resolved',
                      badgeColor: Colors.grey,
                      title: 'Coastal Weather Alert',
                      location: 'Trivandrum Coast',
                      description:
                          'Atmospheric conditions stabilized. Fishing advisory withdrawn. Normalcy restored.',
                      time: '04:20 PM',
                      timeAgo: 'Yesterday',
                      actionText: 'History ↺',
                      actionColor: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isEmbedded
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

  Widget _buildSectionDivider(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
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
