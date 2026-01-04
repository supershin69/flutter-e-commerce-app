import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';

class ProductDetails extends StatefulWidget {
  ProductDetails({super.key});

  @override
  State<StatefulWidget> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetails> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text("Hello"),
        backgroundColor: AppColors.appbarColor,
        foregroundColor: Colors.black,
      ),

      body: Center(
        child: Text("Detail Page"),
      ),
    );
  }
}