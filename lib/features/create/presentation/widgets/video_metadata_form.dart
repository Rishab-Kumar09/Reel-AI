import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/core/widgets/custom_text_field.dart';
import 'package:flutter_firebase_app_new/core/constants/app_constants.dart';

class VideoMetadataForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final bool isLoading;

  const VideoMetadataForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<VideoMetadataForm> createState() => _VideoMetadataFormState();
}

class _VideoMetadataFormState extends State<VideoMetadataForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = AppConstants.mainCategories.first;
  final List<String> _selectedTags = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'tags': _selectedTags,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Video Details',
              style: AppTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Title
            CustomTextField(
              label: 'Title',
              hint: 'Enter video title',
              controller: _titleController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            CustomTextField(
              label: 'Description',
              hint: 'Enter video description',
              controller: _descriptionController,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Category Dropdown
            Text(
              'Category',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: AppConstants.mainCategories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // Tags
            Text(
              'Tags',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._selectedTags.map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () {
                        setState(() {
                          _selectedTags.remove(tag);
                        });
                      },
                    )),
                ActionChip(
                  label: const Text('+ Add Tag'),
                  onPressed: () {
                    _showAddTagDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: widget.isLoading ? null : _handleSubmit,
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Upload Video'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final TextEditingController tagController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(
            hintText: 'Enter tag',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final tag = tagController.text.trim();
              if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
                setState(() {
                  _selectedTags.add(tag);
                });
              }
              Get.back();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
