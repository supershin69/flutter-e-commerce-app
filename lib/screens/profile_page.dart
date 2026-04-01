import 'package:e_commerce_frontend/features/personalization/screens/orders/orders.dart';
import 'package:e_commerce_frontend/features/admin/screens/admin_orders_dashboard.dart';
import 'package:e_commerce_frontend/screens/privacy_security_screen.dart';
import 'package:e_commerce_frontend/screens/help_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String _name = 'Loading...';
  String _email = '';
  String? _avatarUrl;
  String _role = 'user';
  bool get _isStaff => _role == 'admin' || _role == 'moderator';

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  /// Fetches the user's name from 'profiles' and email from Auth
  Future<void> _getProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        // Handle unauthenticated state if necessary
        return;
      }

      setState(() {
        _email = user.email ?? 'No Email';
      });

      // Fetch profile data from your Postgres table
      final data = await _supabase
          .from('profiles')
          .select('name, avatar, role')
          .eq('user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _name = data['name'] ?? 'User';
          _avatarUrl = data['avatar']; // If you have avatars implemented
          _role = (data['role']?.toString().trim().isNotEmpty == true) ? data['role'].toString() : 'user';
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $error')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Logs the user out
  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      
      if (mounted) {
        // Navigate to login screen or clear stack
        // Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error signing out')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using an off-white background to make the white list tiles pop
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.brown.shade300))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 20),
                  
                  // Section 1: Shopping
                  _buildSectionHeader('SHOPPING'),
                  _buildSettingsContainer([
                    _buildListTile(
                      icon: Icons.shopping_bag_outlined,
                      title: 'My Orders',
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  if (_isStaff) ...[
                    _buildSectionHeader('ADMIN'),
                    _buildSettingsContainer([
                      _buildListTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Orders: Set Delivery Fee',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersDashboard()));
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // Section 2: Account Settings
                  _buildSectionHeader('SETTINGS'),
                  _buildSettingsContainer([
                    _buildListTile(
                      icon: Icons.lock_outline,
                      title: 'Privacy & Security',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
                        );
                      },
                    ),
                     _buildDivider(),
                    _buildListTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Section 3: Danger Zone (Logout)
                  _buildSettingsContainer([
                    _buildListTile(
                      icon: Icons.logout,
                      title: 'Log Out',
                      textColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      showTrailing: false,
                      onTap: _signOut,
                    ),
                  ]),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // --- Widget Builders ---

  /// The Top Header with Avatar, Name, and Email
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.brown.shade300, width: 2),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.brown.shade100,
            backgroundImage: _avatarUrl != null 
              ? NetworkImage(_avatarUrl!) 
              : null,
            child: _avatarUrl == null
                ? Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 40, 
                      color: Colors.brown.shade800,
                      fontWeight: FontWeight.bold
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _email,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Label for the list group (e.g. "SHOPPING")
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  /// The white container that holds the list tiles
  Widget _buildSettingsContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  /// A single row in the settings list
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    bool showTrailing = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.brown.shade300).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon, 
          color: iconColor ?? Colors.brown.shade300,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: textColor ?? Colors.black87,
        ),
      ),
      trailing: showTrailing 
        ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
        : null,
      onTap: onTap,
    );
  }

  /// A divider line for inside the container
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 60, // Indent to align with text, bypassing icon
    );
  }
}
