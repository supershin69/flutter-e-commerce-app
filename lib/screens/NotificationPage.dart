import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // Theme Constants
  final Color _primaryColor = Colors.brown.shade300;
  final Color _accentColor = Colors.brown.shade700;
  final Color _unreadBg = const Color(0xFFF5F0EB); // Very light brown/beige
  final Color _scaffoldBg = const Color(0xFFFAFAFA); // Off-white for modern feel

  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNotifications();
    subscribeToRealtime();
  }

  Future<void> loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    };

    try {
      final data = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          notifications = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void subscribeToRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: user?.id),
          callback: (payload) {
            setState(() {
              notifications.insert(0, payload.newRecord);
            });
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(String id) async {
    // 1. Optimistic Update (Instant UI feedback)
    final index = notifications.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      setState(() {
        // Create a distinct copy to trigger UI rebuild safely
        final updatedItem = Map<String, dynamic>.from(notifications[index]);
        updatedItem['read'] = true;
        notifications[index] = updatedItem;
      });
    }

    // 2. Background Server Update
    await Supabase.instance.client
        .from('notifications')
        .update({'read': true})
        .eq('id', id);
  }

  /// Helper to format Supabase timestamp to "2m ago", "1h ago"
  String _getTimeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final date = DateTime.parse(createdAt).toLocal();
    final difference = DateTime.now().difference(date);

    if (difference.inDays > 1) {
      return '${date.day}/${date.month}';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: _primaryColor,
                  onRefresh: loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return _buildNotificationItem(n);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> n) {
    final bool read = n['read'] ?? false;
    final String timeAgo = _getTimeAgo(n['created_at']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: read ? Colors.white : _unreadBg,
        borderRadius: BorderRadius.circular(16), // Rounded modern corners
        boxShadow: [
          if (!read) // Subtle lift for unread items
            BoxShadow(
              color: Colors.brown.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: read 
          ? Border.all(color: Colors.grey.shade200) 
          : Border.all(color: Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => markAsRead(n['id']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Icon Container
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: read ? Colors.grey.shade100 : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_rounded,
                    color: read ? Colors.grey.shade400 : _primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // 2. Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n['title'] ?? 'New Message',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                                color: read ? Colors.black87 : Colors.black,
                              ),
                            ),
                          ),
                          if (!read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n['body'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: read ? Colors.grey.shade600 : Colors.brown.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: read ? Colors.grey.shade400 : _primaryColor,
                          fontWeight: read ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 60,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.brown.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no new notifications.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}