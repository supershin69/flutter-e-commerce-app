import 'package:e_commerce_frontend/features/shop/models/order_model.dart';
import 'package:e_commerce_frontend/services/checkout_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerFeeApprovalScreen extends StatefulWidget {
  final String orderId;

  const CustomerFeeApprovalScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<CustomerFeeApprovalScreen> createState() => _CustomerFeeApprovalScreenState();
}

class _CustomerFeeApprovalScreenState extends State<CustomerFeeApprovalScreen> {
  final _checkoutService = CheckoutService();
  final _supabase = Supabase.instance.client;
  final _priceFormatter = NumberFormat.decimalPattern();

  late Future<OrderModel> _orderFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
  }

  Future<OrderModel> _fetchOrder() async {
    final data = await _supabase
        .from('orders')
        .select()
        .eq('id', widget.orderId)
        .single();

    return OrderModel.fromDatabaseMap(Map<String, dynamic>.from(data));
  }

  Future<void> _reload() async {
    setState(() {
      _orderFuture = _fetchOrder();
    });
  }

  String _formatMMK(int value) => '${_priceFormatter.format(value)} MMK';

  Future<void> _accept() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      await _checkoutService.customerAcceptDeliveryFee(widget.orderId);
      if (!mounted) return;
      await _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery fee approved. Your order is now processing.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _reject() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      await _checkoutService.customerRejectDeliveryFee(widget.orderId);
      if (!mounted) return;
      await _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled. Delivery fee was rejected.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Fee Approval'),
      ),
      body: FutureBuilder<OrderModel>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(snapshot.hasError ? 'Error: ${snapshot.error}' : 'Order not found'),
            );
          }

          final order = snapshot.data!;
          final deliveryFee = order.deliveryFee;
          final canRespond = order.customerRespondedAt == null && order.deliveryFeeStatus == 'fee_set' && deliveryFee != null;
          final subtotal = order.totalAmount;
          final totalWithFee = deliveryFee == null ? null : subtotal + deliveryFee;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoTile(label: 'Order ID', value: order.id),
                const SizedBox(height: 12),
                _InfoTile(label: 'Status', value: order.status),
                const SizedBox(height: 12),
                _InfoTile(label: 'Address', value: order.address),
                const SizedBox(height: 12),
                _InfoTile(label: 'Phone', value: order.phoneNumber ?? ''),
                const SizedBox(height: 16),
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (order.items.isEmpty)
                  const Text('No items found')
                else
                  ...order.items.map((item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: item.variantName != null ? Text(item.variantName!) : null,
                      trailing: Text('${item.quantity} × ${_formatMMK(item.price)}'),
                    );
                  }),
                const Divider(height: 28),
                _InfoTile(label: 'Subtotal', value: _formatMMK(subtotal)),
                const SizedBox(height: 8),
                _InfoTile(label: 'Delivery Fee', value: deliveryFee == null ? 'Pending' : _formatMMK(deliveryFee)),
                const SizedBox(height: 8),
                _InfoTile(label: 'Total', value: totalWithFee == null ? 'Pending' : _formatMMK(totalWithFee)),
                const SizedBox(height: 20),
                if (!canRespond)
                  Text(
                    order.customerRespondedAt != null
                        ? 'You already responded to this delivery fee.'
                        : 'Delivery fee is not ready for approval.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (!canRespond || _isSubmitting) ? null : _reject,
                        child: _isSubmitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Cancel Order'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (!canRespond || _isSubmitting) ? null : _accept,
                        child: _isSubmitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Approve Fee'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

