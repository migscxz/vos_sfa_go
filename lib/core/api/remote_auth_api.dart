import 'dart:convert';
import 'package:http/http.dart' as http;

class RemoteAuthApi {
  // Make sure this matches your actual server IP/Port
  final String baseUrl = "http://goatedcodoer:8056/items";

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user?limit=-1'));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        } else if (jsonResponse is List) {
          return List<Map<String, dynamic>>.from(jsonResponse);
        }
        return [];
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error fetching users: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllSalesmen() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/salesman?limit=-1'));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        } else if (jsonResponse is List) {
          return List<Map<String, dynamic>>.from(jsonResponse);
        }
        return [];
      } else {
        throw Exception('Failed to load salesmen');
      }
    } catch (e) {
      throw Exception('Network error fetching salesmen: $e');
    }
  }

  // ✅ ADD THIS METHOD
  Future<List<Map<String, dynamic>>> fetchAllDepartments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/department?limit=-1'));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        } else if (jsonResponse is List) {
          return List<Map<String, dynamic>>.from(jsonResponse);
        }
        return [];
      } else {
        throw Exception('Failed to load departments');
      }
    } catch (e) {
      throw Exception('Network error fetching departments: $e');
    }
  }
}
