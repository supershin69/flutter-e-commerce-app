import 'package:e_commerce_frontend/utils/colors.dart';
import 'package:flutter/material.dart';

class ProductActionBar extends StatefulWidget{
  final Function(int quantity) addToCart;
  const ProductActionBar({super.key, required this.addToCart});

  @override
  State<StatefulWidget> createState() => _ProductActionState();
}
class _ProductActionState extends State<ProductActionBar> {


    int quantity = 1;

    void increment() {
      setState(() {
        quantity++;
      });
    }

    void decrement() {
      if (quantity > 1) {
        setState(() {
          quantity--;
        });
      }
    }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
  
    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(0.1)
            )
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Quantity add/decrease part
            Row(
              children: [
                Container(
                  margin: EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.appbarColor,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: IconButton(
                    color: Colors.white,
                    splashColor: Colors.transparent,
                    onPressed: decrement, 
                    icon: const Icon(Icons.remove)
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: BoxBorder.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Text(
                    quantity.toString(),
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: AppColors.appbarColor,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: IconButton(
                    color: Colors.white,
                    onPressed: increment, 
                    icon: Icon(Icons.add)
                  ),
                )
              ],
            ),
            GestureDetector(
              onTap: () => widget.addToCart(quantity),
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.appbarColor,
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Text(
                  "Add to Cart",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}