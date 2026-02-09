import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:e_commerce_frontend/models/cart_item_model.dart';
import 'package:e_commerce_frontend/models/user_model.dart';
import 'package:e_commerce_frontend/services/cart_service.dart';
import 'package:e_commerce_frontend/services/user_service.dart';
import 'package:e_commerce_frontend/services/checkout_service.dart';
import 'package:e_commerce_frontend/features/shop/models/order_model.dart';
import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:e_commerce_frontend/features/shop/screens/checkout/order_success_page.dart';

class CheckoutVoucher extends StatefulWidget {
  const CheckoutVoucher({super.key});

  @override
  State<CheckoutVoucher> createState() => _CheckoutVoucherState();
}

class _CheckoutVoucherState extends State<CheckoutVoucher> {
  final supabase = Supabase.instance.client;
  final CartService _cartService = CartService();
  final UserService _userService = UserService();
  final CheckoutService _checkoutService = CheckoutService();
  final _formKey = GlobalKey<FormState>();
  
  late Future<List<CartItem>> _cartItemsFuture;
  late Future<UserModel?> _userFuture;
  late DateTime _orderDate;
  int _baseTotalPrice = 0; // Base price without delivery fee
  int _deliveryFee = 3000; // Default to Standard delivery
  int _totalPrice = 0; // Total including delivery fee
  
  // Form controllers for shipping details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();
  
  // Delivery and Payment options
  String _deliveryMethod = 'Standard'; // 'Standard' or 'Express'
  String _paymentMethod = 'Cash on Delivery'; // 'Cash on Delivery', 'KPay', 'WavePay', or 'AYAPay'
  
  bool _isSubmitting = false;
  bool _hasShippingInfo = false;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _orderDate = DateTime.now();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _cartItemsFuture = _cartService.getCartItems();
      _userFuture = _userService.getCurrentUser();
    });
    
    final total = await _cartService.getTotalPrice();
    if (mounted) {
      setState(() {
        _baseTotalPrice = total;
        _deliveryFee = 3000; // Standard delivery default
        _totalPrice = _baseTotalPrice + _deliveryFee;
      });
    }
    
    // Check if user has shipping info after user data loads
    _userFuture.then((user) {
      if (mounted) {
        if (user != null) {
          // User is logged in
          final hasPhone = user.phoneNumber.isNotEmpty && user.phoneNumber != 'N/A';
          final hasAddress = user.shippingAddress.isNotEmpty && user.shippingAddress != 'N/A';
          
          setState(() {
            _isGuest = false;
            _hasShippingInfo = hasPhone && hasAddress;
            
            // Auto-fill from user profile
            _nameController.text = user.name;
            if (hasPhone) {
              _phoneController.text = user.phoneNumber;
            }
            // Note: User model stores shippingAddress as String, so we can't auto-fill city/street
            // User will need to enter them separately
          });
        } else {
          // Guest user - show empty fields
          setState(() {
            _isGuest = true;
            _hasShippingInfo = false;
          });
        }
      }
    });
  }

  void _updateDeliveryFee() {
    setState(() {
      _deliveryFee = _deliveryMethod == 'Express' ? 5000 : 3000;
      _totalPrice = _baseTotalPrice + _deliveryFee;
    });
  }

  /// Format currency with comma separators (e.g., 6,000,000 MMK)
  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(amount)} MMK';
  }

  Future<void> _onConfirmOrder() async {
    // Check if user is logged in - user_id is required (NOT NULL constraint)
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to complete your order'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Always validate form if logged-in user doesn't have shipping info
    if (!_hasShippingInfo) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    // Validate transaction ID for mobile banking
    final isMobileBanking = _paymentMethod == 'KPay' || _paymentMethod == 'WavePay' || _paymentMethod == 'AYAPay';
    if (isMobileBanking) {
      final transactionId = _transactionIdController.text.trim();
      if (transactionId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the last 6 digits of your Transaction ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (transactionId.length != 6 || !RegExp(r'^\d+$').hasMatch(transactionId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction ID must be exactly 6 digits'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Get final customer details
    final user = await _userFuture;
    final customerName = user?.name ?? _nameController.text.trim();
    
    final phoneNumber = _hasShippingInfo
        ? (user?.phoneNumber ?? _phoneController.text.trim())
        : _phoneController.text.trim();
    
    final city = _cityController.text.trim();
    final street = _streetController.text.trim();

    // Validate that we have all required fields
    if (customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide your name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (city.isEmpty || street.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide both city and street address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final cartItems = await _cartItemsFuture;
      
      if (cartItems.isEmpty) {
        throw Exception('Cart is empty');
      }

      // Save shipping info to user profile if it wasn't there before
      // Note: User model stores address as string, so we'll combine city and street
      if (!_hasShippingInfo) {
        final combinedAddress = '$street, $city';
        await _userService.updateShippingInfo(
          phoneNumber: phoneNumber,
          shippingAddress: combinedAddress,
        );
      }

      // Map payment method to payment_status enum
      // Adjust these values to match your actual payment_status enum values
      String paymentStatus = 'pending';
      if (_paymentMethod == 'Cash on Delivery') {
        paymentStatus = 'pending'; // or 'cod' depending on your enum
      } else if (isMobileBanking) {
        paymentStatus = 'pending'; // Will be updated after transaction verification
      }

      // Map delivery method to determine status
      // Adjust status values to match your actual order_status enum values
      String orderStatus = 'processing';

      // Create order (supports both authenticated and guest users)
      OrderModel? order;
      try {
        // Map payment method to database format (enum values must match exactly)
        // Database enum expects lowercase with hyphens: 'k-pay', 'wave-pay', 'aya-pay'
        String? dbPaymentMethod;
        if (_paymentMethod == 'Cash on Delivery') {
          dbPaymentMethod = 'cash-on-delivery';
        } else if (_paymentMethod == 'KPay') {
          dbPaymentMethod = 'k-pay'; // Lowercase with hyphen
        } else if (_paymentMethod == 'WavePay') {
          dbPaymentMethod = 'wave-pay'; // Lowercase with hyphen
        } else if (_paymentMethod == 'AYAPay') {
          dbPaymentMethod = 'aya-pay'; // Lowercase with hyphen
        }

        // Map delivery method to shipping_method (database column name)
        String? dbShippingMethod;
        if (_deliveryMethod == 'Standard') {
          dbShippingMethod = 'standard';
        } else if (_deliveryMethod == 'Express') {
          dbShippingMethod = 'express';
        }

        // Get transaction ID if mobile banking is selected
        final transactionId = isMobileBanking ? _transactionIdController.text.trim() : null;

        order = await _checkoutService.createOrder(
          userId: currentUser.id, // Required - user must be logged in
          items: cartItems,
          totalAmount: _totalPrice, // Already an int
          city: city,
          street: street,
          phoneNumber: phoneNumber,
          customerName: customerName,
          status: orderStatus,
          paymentStatus: paymentStatus,
          paymentMethod: dbPaymentMethod,
          shippingMethod: dbShippingMethod, // Note: database uses shipping_method
          transactionId: transactionId,
        );
      } catch (e) {
        // Re-throw with more context
        throw Exception('Failed to create order: $e');
      }

      if (order == null) {
        throw Exception('Order creation returned null. Please check your database connection and ensure the orders table exists.');
      }

      // Clear cart
      await _cartService.clearCart();

      if (mounted) {
        // Navigate to success page - order is guaranteed to be non-null here
        final confirmedOrder = order!;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderSuccessPage(order: confirmedOrder),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        // Show detailed error message
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        
        // Also print to console for debugging
        debugPrint('Order creation error: $e');
      }
    }
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
          onPressed: _onCancel,
        ),
        title: const Text(
          'Order Summary',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([_cartItemsFuture, _userFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final results = snapshot.data as List;
          final cartItems = results[0] as List<CartItem>;
          final user = results[1] as UserModel?;

          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: muted),
                  const SizedBox(height: 16),
                  const Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              key: const PageStorageKey('checkout_scroll'),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Voucher Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voucher ID',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FutureBuilder<String>(
                                  future: Future.value('Order #${_orderDate.millisecondsSinceEpoch.toString().substring(7)}'),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? 'Order',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(_orderDate),
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Customer Information Section
                  _buildSectionHeader('Customer Information'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name - Show input for guests or if user doesn't have name
                        if (_isGuest || user?.name == null || user!.name.isEmpty)
                          _buildNameInput(muted)
                        else
                          _buildInfoRow(Icons.person_outline, 'Name', user.name),
                        const Divider(height: 24),
                        // Phone Number - Show input if missing or guest
                        if (_isGuest || !_hasShippingInfo)
                          _buildPhoneInput(muted)
                        else
                          _buildInfoRow(Icons.phone_outlined, 'Phone', user?.phoneNumber ?? 'N/A'),
                        const Divider(height: 24),
                        // City and Street - Show inputs if missing or guest
                        if (_isGuest || !_hasShippingInfo) ...[
                          _buildCityInput(muted),
                          const Divider(height: 24),
                          _buildStreetInput(muted),
                        ] else ...[
                          // For logged-in users with saved info, we can't display city/street separately
                          // since user model stores it as a single string
                          _buildInfoRow(Icons.location_on_outlined, 'Address', user?.shippingAddress ?? 'N/A'),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Delivery Method Section
                  _buildSectionHeader('Delivery Method'),
                  const SizedBox(height: 12),
                  _buildDeliveryMethodSelector(card, border, accent, muted),

                  const SizedBox(height: 24),

                  // Payment Method Section
                  _buildSectionHeader('Payment Method'),
                  const SizedBox(height: 12),
                  // Use StatefulBuilder to localize state updates and prevent full rebuild
                  StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return _buildPaymentMethodSelector(card, border, accent, muted, setState);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Order Items Section
                  _buildSectionHeader('Order Items'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cartItems.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: border),
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return _buildOrderItem(item, muted);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Total Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: TextStyle(
                                color: muted,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatCurrency(_baseTotalPrice),
                              style: TextStyle(
                                color: muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delivery Fee (${_deliveryMethod})',
                              style: TextStyle(
                                color: muted,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatCurrency(_deliveryFee),
                              style: TextStyle(
                                color: muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatCurrency(_totalPrice),
                              style: TextStyle(
                                color: accent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : _onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _onConfirmOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Confirm Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.brown.shade300),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput(Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone_outlined, size: 20, color: Colors.brown.shade300),
            const SizedBox(width: 12),
            const Text(
              'Phone Number',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: 'Enter your phone number',
            hintStyle: TextStyle(color: muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: muted),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNameInput(Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, size: 20, color: Colors.brown.shade300),
            const SizedBox(width: 12),
            const Text(
              'Name',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          keyboardType: TextInputType.name,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: muted),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCityInput(Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_city, size: 20, color: Colors.brown.shade300),
            const SizedBox(width: 12),
            const Text(
              'City',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cityController,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: 'e.g., Mandalay',
            hintStyle: TextStyle(color: muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: muted),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your city';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStreetInput(Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: Colors.brown.shade300),
            const SizedBox(width: 12),
            const Text(
              'Street Address',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _streetController,
          keyboardType: TextInputType.streetAddress,
          decoration: InputDecoration(
            hintText: 'e.g., 73 x 74 or MIIT',
            hintStyle: TextStyle(color: muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: muted),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your street address';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTransactionIdInput(Color accent, Color muted, Color border) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long_outlined, size: 20, color: accent),
            const SizedBox(width: 12),
            const Text(
              'Last 6 digits of Transaction ID',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _transactionIdController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: "Enter the ID from your bank's success screen",
            hintStyle: TextStyle(color: muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            counterText: '',
          ),
          style: TextStyle(color: AppColors.textDark),
          validator: (value) {
            final isMobileBanking = _paymentMethod == 'KPay' || _paymentMethod == 'WavePay' || _paymentMethod == 'AYAPay';
            if (isMobileBanking) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the last 6 digits of Transaction ID';
              }
              if (value.trim().length != 6 || !RegExp(r'^\d+$').hasMatch(value.trim())) {
                return 'Transaction ID must be exactly 6 digits';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOrderItem(CartItem item, Color muted) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl.isNotEmpty
                ? Image.network(
                    item.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${item.quantity}',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatCurrency(item.price),
                      style: TextStyle(
                        color: Colors.brown.shade300,
                        fontSize: 15,
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

  Widget _buildDeliveryMethodSelector(Color card, Color border, Color accent, Color muted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _buildDeliveryOption(
            'Standard Delivery',
            _formatCurrency(3000),
            'Standard',
            Icons.local_shipping_outlined,
            card,
            border,
            accent,
            muted,
          ),
          const SizedBox(height: 12),
          _buildDeliveryOption(
            'Express Delivery',
            _formatCurrency(5000),
            'Express',
            Icons.flash_on_outlined,
            card,
            border,
            accent,
            muted,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOption(
    String title,
    String price,
    String value,
    IconData icon,
    Color card,
    Color border,
    Color accent,
    Color muted,
  ) {
    final isSelected = _deliveryMethod == value;
    return InkWell(
      onTap: () {
        setState(() {
          _deliveryMethod = value;
          _updateDeliveryFee();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.1) : card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? accent : muted,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? accent : AppColors.textDark,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: accent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector(Color card, Color border, Color accent, Color muted, [StateSetter? localSetState]) {
    final isMobileBanking = _paymentMethod == 'KPay' || _paymentMethod == 'WavePay' || _paymentMethod == 'AYAPay';
    
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            _buildPaymentOption(
              'Cash on Delivery',
              'Pay when you receive',
              'Cash on Delivery',
              Icons.money_outlined,
              card,
              border,
              accent,
              muted,
              localSetState,
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              'K-Pay',
              'Mobile Banking',
              'KPay',
              Icons.qr_code_scanner,
              card,
              border,
              accent,
              muted,
              localSetState,
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              'Wave Pay',
              'Mobile Banking',
              'WavePay',
              Icons.qr_code_scanner,
              card,
              border,
              accent,
              muted,
              localSetState,
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              'AYA Pay',
              'Mobile Banking',
              'AYAPay',
              Icons.qr_code_scanner,
              card,
              border,
              accent,
              muted,
              localSetState,
            ),
          // Show QR code and transaction ID input if mobile banking is selected
          if (isMobileBanking) ...[
            const SizedBox(height: 16),
            Divider(color: border),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Scan to Pay label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 20, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Scan to Pay',
                        style: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Instruction text
                  Text(
                    'Please scan the QR code and complete your payment.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // QR Code Image
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: Image.asset(
                      _getQRCodeAssetPath(),
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: Colors.grey[400], size: 48),
                              const SizedBox(height: 8),
                              Text(
                                'QR code not found',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Transaction ID input field
                  _buildTransactionIdInput(accent, muted, border),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildPaymentOption(
    String title,
    String subtitle,
    String value,
    IconData icon,
    Color card,
    Color border,
    Color accent,
    Color muted,
    StateSetter? localSetState,
  ) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () {
        // Use local setState if provided (from StatefulBuilder), otherwise use widget's setState
        if (localSetState != null) {
          localSetState(() {
            _paymentMethod = value;
            // Clear transaction ID if switching away from mobile banking
            if (value == 'Cash on Delivery') {
              _transactionIdController.clear();
            }
          });
        } else {
          setState(() {
            _paymentMethod = value;
            // Clear transaction ID if switching away from mobile banking
            if (value == 'Cash on Delivery') {
              _transactionIdController.clear();
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.1) : card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? accent : muted,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? accent : AppColors.textDark,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: accent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  /// Get the QR code asset path based on selected payment method
  String _getQRCodeAssetPath() {
    switch (_paymentMethod) {
      case 'KPay':
        return 'assets/images/payment/kpay.jpg';
      case 'WavePay':
        return 'assets/images/payment/wave_pay.png';
      case 'AYAPay':
        return 'assets/images/payment/aya_pay.png';
      default:
        return 'assets/images/payment/kpay.jpg'; // Default fallback
    }
  }
}
