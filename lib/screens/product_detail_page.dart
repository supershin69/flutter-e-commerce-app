import 'package:e_commerce_frontend/widgets/product_action_bar.dart';
import 'package:e_commerce_frontend/widgets/transparent_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProductDetails extends StatefulWidget {
  const ProductDetails({super.key});

  @override
  State<StatefulWidget> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetails> {
  bool isWishlisted = false;

  void onWishlistToggle() {
    setState(() {
      isWishlisted = !isWishlisted;
    });
  }
  void addToCart () {
    
  }
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent
        ),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: TransparentAppbar(isWishlisted: isWishlisted, onWishlistToggle: onWishlistToggle),
        
          body: Column(
            
            children: [
              SizedBox(height: 40,),
              Image.asset('assets/images/airpod.jpg'),
              
            ],
          ),
          bottomNavigationBar: ProductActionBar(addToCart: addToCart),
        ),
      ),
    );
  }
}