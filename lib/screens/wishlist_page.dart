import 'package:flutter/material.dart';

class WishlistPage extends StatelessWidget{
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown.shade300,
        foregroundColor: Colors.black,
        title: Text("My Wishlist"),
      ),
      body: const Center(
        child: Text("Wishlist Page"),
      ),
    );
  }
}