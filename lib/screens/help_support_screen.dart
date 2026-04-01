import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
          'Help & Support',
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
          _buildHeaderSection('Contact Us'),
          const SizedBox(height: 12),
          _buildContactItem(
            context,
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'support@digitalhub.com',
            onTap: () => _launchUrl('mailto:support@digitalhub.com'),
          ),
          _buildContactItem(
            context,
            icon: Icons.send_outlined,
            title: 'Telegram Support',
            subtitle: '@DigitalHub_Support',
            onTap: () => _launchUrl('https://t.me/DigitalHub_Support'),
          ),
          _buildContactItem(
            context,
            icon: Icons.facebook_outlined,
            title: 'Facebook Page',
            subtitle: 'Digital Hub Official',
            onTap: () => _launchUrl('https://facebook.com/DigitalHub'),
          ),
          const SizedBox(height: 32),
          _buildHeaderSection('Frequently Asked Questions'),
          const SizedBox(height: 12),
          _buildFAQItem(
            'How do I track my order?',
            'You can track your order status in the "Orders" section of your profile. We also send notifications for key status changes.',
          ),
          _buildFAQItem(
            'How long does delivery take?',
            'Delivery typically takes 2-5 business days depending on your location and chosen shipping method.',
          ),
          _buildFAQItem(
            'How can I reset my password?',
            'Go to the login screen and tap "Forgot Password". We will send you instructions to reset your password via email.',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final brown = Colors.brown.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: brown.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: brown, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }
}
