import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  int _deliveryFee = 0; // Delivery fee is now TBD (Manual Quote)
  int _totalPrice = 0; // Total including delivery fee
  
  // Form controllers for shipping details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  
  // Delivery option
  String _deliveryMethod = 'Car Gate'; // 'Car Gate' or 'Royal Express'
  
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
        _deliveryFee = 0; // Manual delivery quote system
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
      // Manual delivery quote: delivery fee is set by admin later
      _deliveryFee = 0;
      _totalPrice = _baseTotalPrice + _deliveryFee;
    });
  }

  Future<void> _onConfirmOrder() async {
    // Check if user is logged in - user_id is required (NOT NULL constraint)
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
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

    // Get final customer details
    final user = await _userFuture;
    if (!mounted) return;
    
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
      if (!mounted) return;
      
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
        if (!mounted) return;
      }

      // Map payment method to payment_status enum
      String paymentStatus = 'pending';
      String orderStatus = 'pending';

      // Create order (supports both authenticated and guest users)
      OrderModel? order;
      try {
        // Map delivery method to shipping_method (database column name)
        String? dbShippingMethod;
        if (_deliveryMethod == 'Car Gate') {
          dbShippingMethod = 'standard';
        } else if (_deliveryMethod == 'Royal Express') {
          dbShippingMethod = 'express';
        } else {
          dbShippingMethod = 'standard'; // Default fallback
        }

        order = await _checkoutService.createOrder(
          userId: currentUser.id, // Required - user must be logged in
          items: cartItems,
          totalAmount: _baseTotalPrice, // Delivery fee will be set by admin later
          city: city,
          street: street,
          phoneNumber: phoneNumber,
          customerName: customerName,
          status: orderStatus,
          paymentStatus: paymentStatus,
          paymentMethod: 'cash-on-delivery', // Default for now, will be updated later
          shippingMethod: dbShippingMethod,
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
      if (!mounted) return;

      // Navigate to success page - order is guaranteed to be non-null here
      final confirmedOrder = order;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderSuccessPage(order: confirmedOrder),
        ),
      );
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
                          color: Colors.black.withAlpha(12),
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
                      color: accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withAlpha(77)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '$_baseTotalPrice MMK',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Delivery Fee ($_deliveryMethod)',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              _deliveryFee > 0 ? '$_deliveryFee MMK' : 'TBD',
                              style: TextStyle(
                                color: _deliveryFee > 0 ? muted : accent,
                                fontSize: 14,
                                fontWeight: _deliveryFee > 0 ? FontWeight.normal : FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Total Amount',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              _deliveryFee > 0 ? '$_totalPrice MMK' : '$_baseTotalPrice MMK + Fee',
                              style: TextStyle(
                                color: accent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                      '${item.price} MMK',
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
            'Car Gate',
            'Quote will be provided later',
            'Car Gate',
            Icons.local_shipping_outlined,
            card,
            border,
            accent,
            muted,
          ),
          const SizedBox(height: 12),
          _buildDeliveryOption(
            'Royal Express',
            'Quote will be provided later',
            'Royal Express',
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
          color: isSelected ? accent.withAlpha(25) : card,
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
}
