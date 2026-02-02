// lib/features/callsheet/presentation/callsheet_capture_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';

class CallsheetCapturePage extends StatefulWidget {
  const CallsheetCapturePage({super.key});

  @override
  State<CallsheetCapturePage> createState() => _CallsheetCapturePageState();
}

class _CallsheetCapturePageState extends State<CallsheetCapturePage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  Future<void> _captureFromCamera() async {
    final result = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (result != null) {
      setState(() {
        _image = result;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final result = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (result != null) {
      setState(() {
        _image = result;
      });
    }
  }

  void _attachAndReturn() {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or capture a photo first.')),
      );
      return;
    }
    Navigator.of(context).pop(_image!.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Callsheet Photo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Main card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowBase.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Take or attach a photo for this Sales Order.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textDark,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _captureFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6), // light grey preview bg
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _image == null
                        ? Center(
                      child: Text(
                        'No photo selected yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_image!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _attachAndReturn,
                child: const Text('Attach to Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
