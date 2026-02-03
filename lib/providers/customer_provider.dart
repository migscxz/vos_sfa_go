import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/global_remote_api.dart';
import '../data/models/customer_model.dart';

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final remoteApi = GlobalRemoteApi();
  try {
    final response = await remoteApi.fetchList('http://192.168.0.143:8056/items/customer?limit=-1');
    return response.map((json) => Customer.fromJson(json)).toList();
  } catch (e) {
    throw Exception('Failed to load customers: $e');
  }
});
