// lib/providers/order_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/order_model.dart';

class OrderListNotifier extends StateNotifier<List<OrderModel>> {
  OrderListNotifier() : super(const []);

  void addOrder(OrderModel order) {
    state = [...state, order];
  }

  void clearAll() {
    state = const [];
  }
}

final orderListProvider =
StateNotifierProvider<OrderListNotifier, List<OrderModel>>(
      (ref) => OrderListNotifier(),
);
