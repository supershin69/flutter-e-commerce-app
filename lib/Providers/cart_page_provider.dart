import 'package:flutter/material.dart';

class CartPageProvider extends ChangeNotifier{
  int? quantity; // null = no item in cart

  bool get hasItem => quantity != null;

  void setItem([int qty = 1]) {
    quantity = qty;
    notifyListeners();
  }

  void clear() {
    quantity = null;
    notifyListeners();
  }

  void increment() {
    if (quantity == null) return;
    quantity = quantity! + 1;
    notifyListeners();
  }

  void decrement() {
    if (quantity == null || quantity! <= 1) return;
    quantity = quantity! - 1;
    notifyListeners();
  }
}