import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:e_commerce_frontend/features/shop/models/order_model.dart';
import 'package:e_commerce_frontend/models/cart_item_model.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final OrderModel? initialOrder;

  OrderDetailScreen({
    super.key,
    required OrderModel order,
  })  : orderId = order.id,
        initialOrder = order;

  const OrderDetailScreen.byId({
    super.key,
    required this.orderId,
  }) : initialOrder = null;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _supabase = Supabase.instance.client;

  late Future<OrderModel> _orderFuture;
  bool _isActionLoading = false;
  
  // Payment selection state
  String _paymentMethod = 'KPay'; // Default online method
  final TextEditingController _transactionIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrder();
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
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
    await _orderFuture;
  }

  Future<void> _submitPayment(String orderId) async {
    final tid = _transactionIdController.text.trim();
    final isMobileBanking = _paymentMethod == 'KPay' || _paymentMethod == 'WavePay' || _paymentMethod == 'AYAPay';
    
    if (isMobileBanking) {
      if (tid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter transaction ID'), backgroundColor: Colors.red),
        );
        return;
      }
      if (tid.length != 20 || !RegExp(r'^[0-9]+$').hasMatch(tid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction ID must be 20 digits'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      // Map display name to DB enum value
      String dbPaymentMethod = _paymentMethod;
      if (_paymentMethod == 'Cash on Delivery') {
        dbPaymentMethod = 'cash-on-delivery';
      }

      await _supabase.rpc(
        'submit_payment',
        params: {
          'p_order_id': orderId,
          'p_payment_method': dbPaymentMethod,
          'p_transaction_id': isMobileBanking ? tid : null,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment submitted successfully')),
      );
      _transactionIdController.clear();
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _acceptDeliveryFee(String orderId) async {
    setState(() {
      _isActionLoading = true;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Please login to continue');
      }
      await _supabase.rpc(
        'accept_delivery_fee',
        params: {'p_order_id': orderId, 'p_user_id': user.id},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery fee accepted')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _rejectDeliveryFee(String orderId) async {
    setState(() {
      _isActionLoading = true;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Please login to continue');
      }
      await _supabase.rpc(
        'reject_delivery_fee',
        params: {'p_order_id': orderId, 'p_user_id': user.id},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery fee rejected')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OrderModel>(
      future: _orderFuture,
      builder: (context, snapshot) {
        final order = snapshot.data ?? widget.initialOrder;

        if (snapshot.connectionState == ConnectionState.waiting && order == null) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError && order == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Order Details',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        return Stack(
          children: [
            _OrderDetailView(
              order: order!,
              isRefreshing: snapshot.connectionState == ConnectionState.waiting,
              isActionLoading: _isActionLoading,
              onAcceptDeliveryFee: () => _acceptDeliveryFee(order.id),
              onRejectDeliveryFee: () => _rejectDeliveryFee(order.id),
              onSubmitPayment: (method) => _submitPayment(order.id),
              selectedPaymentMethod: _paymentMethod,
              transactionIdController: _transactionIdController,
              onPaymentMethodChanged: (method) {
                setState(() {
                  _paymentMethod = method;
                });
              },
            ),
            if (_isActionLoading)
              Container(
                color: Colors.black.withAlpha(50),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  final OrderModel order;
  final bool isRefreshing;
  final bool isActionLoading;
  final VoidCallback onAcceptDeliveryFee;
  final VoidCallback onRejectDeliveryFee;
  final Function(String) onSubmitPayment;
  final String selectedPaymentMethod;
  final TextEditingController transactionIdController;
  final Function(String) onPaymentMethodChanged;

  const _OrderDetailView({
    required this.order,
    required this.isRefreshing,
    required this.isActionLoading,
    required this.onAcceptDeliveryFee,
    required this.onRejectDeliveryFee,
    required this.onSubmitPayment,
    required this.selectedPaymentMethod,
    required this.transactionIdController,
    required this.onPaymentMethodChanged,
  });

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Get color for order status badge
  /// Returns appropriate color based on status value from database
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'canceled':
      case 'cancelled': // Support both spellings
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get color for payment status badge
  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'awaiting_verification':
        return Colors.blue;
      case 'failed':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Format status text to be capitalized (e.g., "Pending" instead of "pending")
  String _formatStatus(String status) {
    if (status.isEmpty) return status;
    // Handle underscores like awaiting_verification -> Awaiting Verification
    return status.split('_').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Format shipping method for display
  String _formatShippingMethod(String? method) {
    if (method == null || method.isEmpty) return 'N/A';
    final normalized = method.toLowerCase();
    switch (normalized) {
      case 'standard':
      case 'car gate':
        return 'Car Gate';
      case 'express':
      case 'royal express':
        return 'Royal Express';
      default:
        return method[0].toUpperCase() + method.substring(1).toLowerCase();
    }
  }

  /// Format Order ID to show only first 8 characters in uppercase with # prefix
  /// Example: "7b7bc9db-7179-4064-a1a7-c5ede0" -> "#7B7BC9DB"
  String _formatOrderId(String orderId) {
    if (orderId.isEmpty) return '#N/A';
    // Remove hyphens and take first 8 characters, convert to uppercase
    final cleanId = orderId.replaceAll('-', '');
    final shortId = cleanId.length >= 8 ? cleanId.substring(0, 8) : cleanId;
    return '#${shortId.toUpperCase()}';
  }

  /// Copy full order ID to clipboard and show toast
  Future<void> _copyOrderIdToClipboard(BuildContext context, String orderId) async {
    await Clipboard.setData(ClipboardData(text: orderId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order ID copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Copy transaction ID to clipboard and show toast
  Future<void> _copyTransactionIdToClipboard(BuildContext context, String transactionId) async {
    await Clipboard.setData(ClipboardData(text: transactionId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction ID copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Copy receipt URL to clipboard and show toast
  Future<void> _copyReceiptUrlToClipboard(BuildContext context, String receiptUrl) async {
    await Clipboard.setData(ClipboardData(text: receiptUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt URL copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Format currency with comma separators (e.g., 6,000,000 MMK)
  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(amount)} MMK';
  }

  String _getQRCodeAssetPath(String method) {
    switch (method) {
      case 'KPay':
        return 'assets/images/payment/kpay.jpg';
      case 'WavePay':
        return 'assets/images/payment/wave_pay.png';
      case 'AYAPay':
        return 'assets/images/payment/aya_pay.png';
      default:
        return 'assets/images/payment/kpay.jpg';
    }
  }

  Widget _buildPaymentOption(String label, String value, IconData icon, Color card, Color border, Color accent, Color muted) {
    final isSelected = selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () => onPaymentMethodChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accent : muted,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textDark : muted,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: accent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const card = Colors.white;
    const border = Color(0xFFE0E0E0);
    const muted = Color(0xFF9AA0A6);
    final accent = Colors.brown.shade300;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header - Modernized
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order ID',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  _formatOrderId(order.id),
                                  style: const TextStyle(
                                    color: Color(0xFF7B7BC9),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18, color: Color(0xFF7B7BC9)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _copyOrderIdToClipboard(context, order.id),
                                  tooltip: 'Copy full Order ID',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status).withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(order.status),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatStatus(order.status),
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Payment Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getPaymentStatusColor(order.paymentStatus).withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getPaymentStatusColor(order.paymentStatus),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _formatStatus(order.paymentStatus),
                              style: TextStyle(
                                color: _getPaymentStatusColor(order.paymentStatus),
                                fontSize: 12, // Slightly smaller than order status
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(order.orderDate),
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (isRefreshing) const LinearProgressIndicator(minHeight: 2),
            if (isRefreshing) const SizedBox(height: 12),

            if (order.deliveryFee != null && order.deliveryFee! > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Fee Information',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Delivery Fee:',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatCurrency(order.deliveryFee!),
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (order.deliveryFeeStatus == 'fee_set' && order.status.toLowerCase() == 'pending' && order.customerRespondedAt == null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isActionLoading ? null : onAcceptDeliveryFee,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isActionLoading ? null : onRejectDeliveryFee,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Reject',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          order.deliveryFeeStatus == 'customer_accepted'
                              ? '✓ You have accepted this delivery fee.'
                              : order.deliveryFeeStatus == 'customer_rejected'
                                  ? '✕ You have rejected this delivery fee.'
                                  : 'Status: ${order.deliveryFeeStatus ?? "Unknown"}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: order.deliveryFeeStatus == 'customer_accepted' ? Colors.green.shade700 : Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Shipping Information - Modernized
            _buildSectionHeader('Shipping Information'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name - Bold, Title size
                  Text(
                    order.customerName ?? 'N/A',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Phone Number
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          order.phoneNumber ?? 'N/A',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Address - Multi-line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.street,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                              ),
                            ),
                            if (order.city.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                order.city,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Shipping Method
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 18, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatShippingMethod(order.shippingMethod),
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Payment Verification - Only show if receipt URL exists
            if (order.receiptUrl != null && order.receiptUrl!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionHeader('Payment Verification'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 18, color: accent),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Payment Receipt',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.receiptUrl!,
                            style: TextStyle(
                              color: accent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.copy, size: 18, color: accent),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _copyReceiptUrlToClipboard(context, order.receiptUrl!),
                          tooltip: 'Copy Receipt URL',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Order Items - Modernized
            _buildSectionHeader('Order Items'),
            const SizedBox(height: 12),
            Column(
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildOrderItem(item, muted, accent),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Payment Section
            if (order.deliveryFeeStatus == 'customer_accepted' && 
                order.paymentStatus != 'paid' && 
                order.paymentStatus != 'awaiting_verification' &&
                (order.status.toLowerCase() == 'pending' || order.status.toLowerCase() == 'processing')) ...[
              _buildSectionHeader('Select Payment Method'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    if (order.codAllowed) ...[
                      _buildPaymentOption('Cash on Delivery', 'Cash on Delivery', Icons.money, card, border, accent, muted),
                      const SizedBox(height: 12),
                    ],
                    _buildPaymentOption('KPay', 'KPay', Icons.account_balance_wallet_outlined, card, border, accent, muted),
                    const SizedBox(height: 12),
                    _buildPaymentOption('WavePay', 'WavePay', Icons.account_balance_wallet_outlined, card, border, accent, muted),
                    const SizedBox(height: 12),
                    _buildPaymentOption('AYAPay', 'AYAPay', Icons.account_balance_wallet_outlined, card, border, accent, muted),
                    
                    if (selectedPaymentMethod != 'Cash on Delivery') ...[
                      const SizedBox(height: 20),
                      // QR Code Image
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Image.asset(
                            _getQRCodeAssetPath(selectedPaymentMethod),
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 200,
                                color: Colors.grey[100],
                                child: Icon(Icons.qr_code_2, size: 64, color: muted),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Transaction ID Input
                      TextFormField(
                        controller: transactionIdController,
                        keyboardType: TextInputType.number,
                        maxLength: 20,
                        decoration: InputDecoration(
                          hintText: 'Enter 20-digit transaction ID',
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please enter the 20-digit reference number.',
                        style: TextStyle(color: muted, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isActionLoading ? null : () => onSubmitPayment(selectedPaymentMethod),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Total Summary Section - High-end receipt style
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.brown.shade50, // Very light brown/cream background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent,
                  width: 2, // Thick brown border
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(order.totalAmount + (order.deliveryFee ?? 0)),
                    style: TextStyle(
                      color: accent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildOrderItem(CartItem item, Color muted, Color accent) {
    final itemTotal = item.price * item.quantity;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image - Rounded
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.imageUrl.isNotEmpty
                ? Image.network(
                    item.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  )
                : Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Variant Name
                if (item.variantName != null && item.variantName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.variantName!,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Quantity and Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Qty: ${item.quantity}',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                      ),
                    ),
                    // Total Price for this item - Bold, bottom right
                    Text(
                      _formatCurrency(itemTotal),
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
