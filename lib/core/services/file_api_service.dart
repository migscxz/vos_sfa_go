import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

class FileApiService {
  // Hardcoded IP as per user request
  static const String _baseUrl = 'http://192.168.0.143:7002';

  Future<String?> uploadFile(File file) async {
    final uri = Uri.parse('$_baseUrl/api/files');

    // Create multipart request
    final request = http.MultipartRequest('POST', uri);

    // Add file
    final fileStream = http.MultipartFile.fromBytes(
      'file',
      await file.readAsBytes(),
      filename: p.basename(file.path),
    );
    request.files.add(fileStream);

    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('File uploaded successfully. Response: $respStr');
        try {
          final json = jsonDecode(respStr);

          // Observed structure: {"ok":true,"file":{"id":"..."}}
          if (json is Map<String, dynamic>) {
            if (json.containsKey('file') && json['file'] is Map) {
              return json['file']['id'] as String?;
            }
            // Fallbacks
            if (json.containsKey('data') && json['data'] is Map) {
              return json['data']['id'] as String?;
            }
            if (json.containsKey('id')) {
              return json['id'] as String?;
            }
          }

          return null;
        } catch (e) {
          debugPrint('Error parsing upload response: $e');
          return null;
        }
      } else {
        debugPrint('File upload failed: ${response.statusCode} - $respStr');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  Future<bool> uploadAttachmentMetadata(Map<String, dynamic> data) async {
    final uri = Uri.parse(
      'http://goatedcodoer:8056/items/sales_order_attachment',
    );
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Metadata uploaded successfully');
        return true;
      } else {
        debugPrint(
          'Metadata upload failed: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading metadata: $e');
      return false;
    }
  }

  // Helper to test connection if needed
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
