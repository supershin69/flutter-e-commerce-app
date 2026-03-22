import 'package:e_commerce_frontend/features/shop/models/order_model.dart';
import 'package:e_commerce_frontend/services/checkout_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOrdersDashboard extends StatefulWidget {
  const AdminOrdersDashboard({super.key});

  @override
  State<AdminOrdersDashboard> createState() => _AdminOrdersDashboardState();
}

class _AdminOrdersDashboardState extends State<AdminOrdersDashboard> {
  final _checkoutService = CheckoutService();
  final _priceFormatter = NumberFormat.decimalPattern();
  final _supabase = Supabase.instance.client;

  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _checkoutService.getOrdersPendingDeliveryFeeForAdmin();
  }

  Future<void> _reload() async {
    setState(() {
      _ordersFuture = _checkoutService.getOrdersPendingDeliveryFeeForAdmin();
    });
    await _ordersFuture;
  }

  String _formatMMK(int value) => '${_priceFormatter.format(value)} MMK';

  Future<void> _setFeeDialog(OrderModel order) async {
    final controller = TextEditingController(text: order.deliveryFee?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final deliveryFee = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Delivery Fee'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Delivery fee (MMK)',
              ),
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null) return 'Enter a number';
                if (parsed < 0) return 'Must be >= 0';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(context, int.parse(controller.text.trim()));
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (deliveryFee == null) return;

    try {
      await _checkoutService.adminSetDeliveryFee(
        orderId: order.id,
        deliveryFee: deliveryFee,
      );

      try {
        await _supabase.functions.invoke(
          'notify-order-delivery-fee',
          body: {'order_id': order.id},
        );
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery fee set and customer notified')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set fee: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Orders (Delivery Fee)'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Error: ${snapshot.error}')),
                ],
              );
            }
            final orders = snapshot.data ?? const <OrderModel>[];
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No orders waiting for delivery fee')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final status = order.status;
                final fee = order.deliveryFee;
                final feeStatus = order.deliveryFeeStatus ?? '';
                final subtitleLines = <String?>[
                  order.customerName?.isNotEmpty == true ? 'Customer: ${order.customerName}' : null,
                  order.phoneNumber?.isNotEmpty == true ? 'Phone: ${order.phoneNumber}' : null,
                  order.address.isNotEmpty ? 'Address: ${order.address}' : null,
                  'Subtotal: ${_formatMMK(order.totalAmount)}',
                  fee == null ? 'Delivery fee: Pending' : 'Delivery fee: ${_formatMMK(fee)}',
                ].whereType<String>().toList();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Order ${order.id.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              status,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...subtitleLines.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(t),
                            )),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                feeStatus.isEmpty ? '' : 'Fee status: $feeStatus',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _setFeeDialog(order),
                              child: const Text('Set Fee'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
