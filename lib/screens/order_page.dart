import 'package:flutter/material.dart';

class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown.shade300,
        foregroundColor: Colors.black,
        title: Text("My Orders"),
      ),
      body: const Center(
        child: Text("Order Page"),
      ),
    );
  }
}