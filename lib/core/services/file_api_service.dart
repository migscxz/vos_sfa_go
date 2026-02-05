import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FileApiService {
  // Hardcoded IP as per user request
  static const String _baseUrl = 'http://192.168.0.143:7002';

  Future<bool> uploadFile(File file) async {
    final uri = Uri.parse('$_baseUrl/api/files');

    // Create multipart request
    final request = http.MultipartRequest('POST', uri);

    // Add file
    final fileStream = http.MultipartFile.fromBytes(
      'file',
      await file.readAsBytes(),
      filename: file.path.split('/').last,
    );
    request.files.add(fileStream);

    try {
      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('File uploaded successfully');
        return true;
      } else {
        final respStr = await response.stream.bytesToString();
        debugPrint('File upload failed: ${response.statusCode} - $respStr');
        throw Exception(
          'Upload failed with status ${response.statusCode}: $respStr',
        );
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
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
