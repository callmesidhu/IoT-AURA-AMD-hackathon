import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.red.shade100,
              radius: 16,
              child: const Icon(Icons.shield, color: Colors.red, size: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section
            Row(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=11',
                  ), // Placeholder image
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Arun Kumar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Premium Member',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Text(
                        'Kerala Region • ID: 893-221',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                  style: IconButton.styleFrom(
                    shape: CircleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // General Section
            _buildSectionHeader('GENERAL'),
            _buildSettingsCard([
              _buildListTile(
                icon: Icons.language,
                iconColor: Colors.blue,
                title: 'Language',
                subtitle: 'English (United Kingdom)',
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.dark_mode_outlined,
                iconColor: Colors.black87,
                title: 'Appearance',
                subtitle: 'Light Mode Active',
                isToggle: true,
                toggleValue: false,
              ),
            ]),
            const SizedBox(height: 24),

            // Resilience & Data Section
            _buildSectionHeader('RESILIENCE & DATA'),
            _buildSettingsCard([
              _buildListTile(
                icon: Icons.notifications_none,
                iconColor: Colors.red,
                iconBgColor: Colors.red.shade50,
                title: 'Alert Preferences',
                subtitle: 'Severe Weather, Seismic Activity',
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.hub_outlined,
                iconColor: Colors.teal,
                iconBgColor: Colors.teal.shade50,
                title: 'Resilience Network',
                subtitle: 'Manage Emergency Contacts',
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.location_on_outlined,
                iconColor: Colors.orange,
                iconBgColor: Colors.orange.shade50,
                title: 'Geolocation Services',
                subtitle: 'Precise Location Active',
                isToggle: true,
                toggleValue: true,
              ),
            ]),
            const SizedBox(height: 24),

            // Support & Legal Section
            _buildSectionHeader('SUPPORT & LEGAL'),
            _buildSettingsCard([
              _buildListTile(
                icon: Icons.info_outline,
                iconColor: Colors.black87,
                title: 'About AURA',
                trailingText: 'v2.4.0',
              ),
              const Divider(height: 1),
              _buildListTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: Colors.black87,
                title: 'Privacy Policy',
              ),
            ]),
            const SizedBox(height: 32),

            // Logout Button
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Footer
            Center(
              child: Column(
                children: [
                  const Text(
                    'AURA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Adaptive Uncertainty & Resilience Architecture',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2024 Resilience Systems Inc.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    Color? iconBgColor,
    required String title,
    String? subtitle,
    bool isToggle = false,
    bool toggleValue = false,
    String? trailingText,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor ?? Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            )
          : null,
      trailing: isToggle
          ? Switch(
              value: toggleValue,
              onChanged: (val) {},
              activeColor: Colors.white,
              activeTrackColor: const Color(
                0xFF4C3EE8,
              ), // Deep purple/blue toggle
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trailingText,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
    );
  }
}
