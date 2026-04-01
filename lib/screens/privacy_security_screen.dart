import 'package:flutter/material.dart';
import '../utils/colors.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brown = Colors.brown.shade300;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: brown, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy & Security',
          style: TextStyle(
            color: brown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSecurityCard(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'Data Encryption',
            description: 'All your personal data, payment information, and transaction history are encrypted using industry-standard protocols to ensure complete privacy.',
          ),
          const SizedBox(height: 16),
          _buildSecurityCard(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Secure Authentication',
            description: 'Your account access is secured through Supabase authentication, providing robust protection against unauthorized login attempts.',
          ),
          const SizedBox(height: 16),
          _buildSecurityCard(
            context,
            icon: Icons.manage_accounts_outlined,
            title: 'Account Controls',
            description: 'You have full control over your profile data. You can update your information or manage your account settings at any time from your profile.',
          ),
          const SizedBox(height: 16),
          _buildSecurityCard(
            context,
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            description: 'Our full legal privacy policy outlines how we collect, use, and protect your data. We are committed to transparency in all our operations.',
            isPlaceholder: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    bool isPlaceholder = false,
  }) {
    final brown = Colors.brown.shade300;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brown.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: brown, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          if (isPlaceholder) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Future: Navigate to full legal policy
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Read Full Policy',
                style: TextStyle(
                  color: brown,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
