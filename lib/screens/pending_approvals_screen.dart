// pending_approvals_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingApprovalsScreen extends StatefulWidget {
  final String? orderId;

  const PendingApprovalsScreen({super.key, this.orderId});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _pendingOrders = [];
        _isLoading = false;
      });
      return;
    }

    final response = await supabase
        .from('orders')
        .select('id, total_amount, delivery_fee, created_at, customer_name, delivery_fee_status, customer_responded_at')
        .eq('user_id', user.id)
        .eq('delivery_fee_status', 'fee_set')
        .filter('customer_responded_at', 'is', null)
        .order('created_at', ascending: false);

    var list = List<Map<String, dynamic>>.from(response);
    final targetId = widget.orderId;
    if (targetId != null && targetId.isNotEmpty) {
      list.sort((a, b) {
        final aIsTarget = a['id']?.toString() == targetId;
        final bIsTarget = b['id']?.toString() == targetId;
        if (aIsTarget == bIsTarget) return 0;
        return aIsTarget ? -1 : 1;
      });
    }

    if (!mounted) return;
    setState(() {
      _pendingOrders = list;
      _isLoading = false;
    });
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Please login to continue');
      }
      await supabase.rpc('accept_delivery_fee', params: {
        'p_order_id': orderId,
        'p_user_id': user.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted!')));
      await _loadPendingOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Please login to continue');
      }
      await supabase.rpc('reject_delivery_fee', params: {
        'p_order_id': orderId,
        'p_user_id': user.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order rejected')));
      await _loadPendingOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: Colors.brown.shade300,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingOrders.isEmpty
              ? const Center(
                  child: Text('No pending approvals'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pendingOrders.length,
                  itemBuilder: (context, index) {
                    final order = _pendingOrders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order['id'].substring(0, 8)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Total: ${order['total_amount']} MMK'),
                            Text(
                              'Delivery Fee: ${order['delivery_fee']} MMK',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              'Date: ${order['created_at'].toString().substring(0, 10)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _acceptOrder(order['id']),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Accept'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _rejectOrder(order['id']),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
