import 'package:e_commerce_frontend/features/shop/controllers/product_controller.dart';
import 'package:e_commerce_frontend/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PriceAlertSheet extends StatefulWidget {
  final Product product;
  const PriceAlertSheet({super.key, required this.product});

  @override
  State<PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends State<PriceAlertSheet> {
  final ProductController _controller = Get.find<ProductController>();
  late int targetPrice;
  bool hasExistingAlert = false;
  late double minRange;
  late double maxRange;

  @override
  void initState() {
    super.initState();
    final existingAlert = _controller.getPriceAlert(widget.product.id);
    hasExistingAlert = existingAlert != null;
    
    maxRange = widget.product.minPrice;
    minRange = maxRange * 0.5; // Allow setting alert down to 50% of current price

    if (hasExistingAlert) {
      targetPrice = existingAlert!.targetPrice;
      // Ensure target price is within range
      if (targetPrice < minRange) minRange = targetPrice.toDouble();
      if (targetPrice > maxRange) targetPrice = maxRange.toInt();
    } else {
      // Default to 90%
      targetPrice = (maxRange * 0.9).toInt();
    }
  }

  void _saveAlert() {
    _controller.setPriceAlert(
      widget.product.id,
      targetPrice,
      productName: widget.product.name,
    );
    Navigator.pop(context);
  }

  void _deleteAlert() {
    _controller.deletePriceAlert(widget.product.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set Price Alert',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Text(
            'Current price: ${widget.product.minPrice.toStringAsFixed(0)} MMK',
            style: const TextStyle(fontSize: 16),
          ),
          
          const SizedBox(height: 30),
          
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Notify me when price drops below:',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          
          const SizedBox(height: 10),
          
          Text(
            '$targetPrice MMK',
            style: const TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),

          const SizedBox(height: 10),
          
          // Using Slider instead of RangeSlider for single value selection
          // as RangeSlider is for selecting a range (min/max), but here we pick one target.
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.brown,
              inactiveTrackColor: Colors.brown.shade100,
              thumbColor: Colors.brown,
              overlayColor: Colors.brown.withAlpha(32),
              valueIndicatorColor: Colors.brown,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: targetPrice.toDouble(),
              min: minRange,
              max: maxRange,
              divisions: 100, // Granular control
              label: targetPrice.toString(),
              onChanged: (value) {
                setState(() {
                  targetPrice = value.round();
                });
              },
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                hasExistingAlert ? 'Update Alert' : 'Save Alert',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          if (hasExistingAlert) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _deleteAlert,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Remove Alert'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
