import 'package:e_commerce_frontend/Providers/cart_page_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartPageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Order',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: cart.quantity == null
          ? const Center(child: Text('Your cart is empty'))
          : Column(
        children: [
          ListTile(
            leading: Image.asset(
              'assets/images/phone.jpg',
              width: 100,
              height: 100,
            ),
            title: const Text('iPhone'),
            subtitle: const Text('Sample Item'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: cart.quantity! > 1 ? cart.decrement : null,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  cart.quantity!.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  onPressed: cart.increment,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
        ],
      ),
    );
  }
}
