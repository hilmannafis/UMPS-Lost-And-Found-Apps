import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/item.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/image_classifier_provider.dart';
import '../../core/providers/item_providers.dart';

class ReportItemPage extends ConsumerStatefulWidget {
  const ReportItemPage({super.key});

  @override
  ConsumerState<ReportItemPage> createState() => _ReportItemPageState();
}

class _ReportItemPageState extends ConsumerState<ReportItemPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tower = TextEditingController();
  final _room = TextEditingController();
  final _contactNumber = TextEditingController();
  
  ItemType _type = ItemType.lost;
  String _selectedCategory = 'electronics';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<XFile> _photos = []; // Use XFile for web compatibility
  bool _submitting = false;
  String? _error;
  bool _classifying = false;
  String? _aiSuggestedCategory;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'electronics', 'name': 'Electronics', 'icon': Icons.phone_android},
    {'id': 'clothing', 'name': 'Clothing', 'icon': Icons.checkroom},
    {'id': 'documents', 'name': 'Documents', 'icon': Icons.description},
    {'id': 'accessories', 'name': 'Accessories', 'icon': Icons.watch},
    {'id': 'books', 'name': 'Books', 'icon': Icons.menu_book},
    {'id': 'bags', 'name': 'Bags', 'icon': Icons.backpack},
    {'id': 'other', 'name': 'Other', 'icon': Icons.category},
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tower.dispose();
    _room.dispose();
    _contactNumber.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _photos.addAll(images);
        _aiSuggestedCategory = null;
      });
      // Classify images with AI
      _classifyImages();
    }
  }

  Future<void> _pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    
    if (image != null) {
      setState(() {
        _photos.add(image);
        _aiSuggestedCategory = null;
      });
      // Classify images with AI
      _classifyImages();
    }
  }

  Future<void> _classifyImages() async {
    if (_photos.isEmpty) return;

    setState(() {
      _classifying = true;
    });

    try {
      final classifier = ref.read(imageClassifierServiceProvider);
      final suggestedCategory = await classifier.classifyImages(_photos);

      if (mounted && suggestedCategory != null) {
        setState(() {
          _selectedCategory = suggestedCategory;
          _aiSuggestedCategory = suggestedCategory;
          _classifying = false;
        });

        // Show notification that AI suggested a category
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI detected: ${_categories.firstWhere((c) => c['id'] == suggestedCategory)['name']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00857A),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'electronics'; // Reset to default
                    _aiSuggestedCategory = null;
                  });
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _classifying = false;
          });
        }
      }
    } catch (e) {
      print('Error classifying images: $e');
      if (mounted) {
        setState(() {
          _classifying = false;
        });
        // Show helpful message if ML Kit is not available
        if (e.toString().contains('MissingPluginException') || 
            e.toString().contains('No implementation found')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI classification requires app rebuild. Please restart the app.'),
              duration: Duration(seconds: 4),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submit() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      setState(() => _error = 'Not authenticated');
      return;
    }

    // Validation
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title');
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a description');
      return;
    }
    if (_tower.text.trim().isEmpty) {
      setState(() => _error = 'Please enter tower number');
      return;
    }
    if (_room.text.trim().isEmpty) {
      setState(() => _error = 'Please enter room number');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Format time as HH:mm:ss
      String? formattedTime;
      if (_selectedTime != null) {
        final hour = _selectedTime!.hour.toString().padLeft(2, '0');
        final minute = _selectedTime!.minute.toString().padLeft(2, '0');
        formattedTime = '$hour:$minute:00';
      }

      // Convert XFile to File for mobile, keep XFile for web
      List<File> photos = [];
      if (!kIsWeb && _photos.isNotEmpty) {
        for (final xFile in _photos) {
          final file = File(xFile.path);
          if (file.existsSync()) {
            photos.add(file);
          } else {
            print('Warning: Photo file not found, skipping: ${xFile.path}');
          }
        }
      }
      
      // Create item immediately (photos upload in background)
      await ref.read(itemRepositoryProvider).create(
            type: _type,
            title: _title.text.trim(),
            description: _description.text.trim(),
            categoryId: _selectedCategory,
            ownerId: profile.id,
            towerNumber: _tower.text.trim(),
            roomNumber: _room.text.trim(),
            photos: photos,
            photosWeb: kIsWeb ? _photos : null,
            contactNumber: _contactNumber.text.trim().isNotEmpty ? _contactNumber.text.trim() : profile.phoneNumber,
            lostFoundDate: _selectedDate,
            lostFoundTime: formattedTime,
          );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item reported successfully! Photos are uploading in the background.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        context.pop();
      }
    } catch (e, stackTrace) {
      print('Error submitting item: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage = 'Failed to report item';
      String detailedError = e.toString();
      
      if (detailedError.contains('storage') || detailedError.contains('Storage')) {
        errorMessage = 'Photo upload failed. The item was created without photos. You can add photos later.';
      } else if (detailedError.contains('permission') || detailedError.contains('Permission')) {
        errorMessage = 'Permission denied. Please check Firebase Storage setup in Firebase Console.';
      } else if (detailedError.contains('network') || detailedError.contains('Network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (detailedError.contains('not set up') || detailedError.contains('not been set up')) {
        errorMessage = 'Firebase Storage not enabled. Please enable it in Firebase Console.';
      } else {
        errorMessage = 'Error: ${detailedError.length > 100 ? detailedError.substring(0, 100) + "..." : detailedError}';
      }
      
      if (mounted) {
        setState(() => _error = errorMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                if (detailedError.contains('not set up') || detailedError.contains('not been set up'))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Go to Firebase Console > Storage > Get Started to enable it.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Report Item', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF00857A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Type Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00857A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.category, color: Color(0xFF00857A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Item Type',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const Text(' *', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeChip(
                            label: 'Lost Item',
                            icon: Icons.search_off,
                            isSelected: _type == ItemType.lost,
                            onTap: () => setState(() => _type = ItemType.lost),
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeChip(
                            label: 'Found Item',
                            icon: Icons.search,
                            isSelected: _type == ItemType.found,
                            onTap: () => setState(() => _type = ItemType.found),
                            color: const Color(0xFF00857A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Basic Information Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00857A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline, color: Color(0xFF00857A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Basic Information',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _title,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g., iPhone 14, Blue Backpack',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.title),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _description,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the item in detail...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Photos Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00857A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.photo_library, color: Color(0xFF00857A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Photos',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (_classifying) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI analyzing...',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_photos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'No photos added',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add photos to help others identify your item',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          itemBuilder: (context, index) {
                    final xFile = _photos[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? FutureBuilder<Uint8List>(
                                    future: xFile.readAsBytes().then((bytes) => Uint8List.fromList(bytes)),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Image.memory(
                                          snapshot.data!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    },
                                  )
                                : Builder(
                                    builder: (context) {
                                      final file = File(xFile.path);
                                      if (file.existsSync()) {
                                        return Image.file(
                                          file,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 120,
                                              height: 120,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        );
                                      } else {
                                        return Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImageFromCamera,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00857A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.category, color: Color(0xFF00857A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Category',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const Text(' *', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Select Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.category),
                        suffixIcon: _classifying
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _aiSuggestedCategory != null && _aiSuggestedCategory == _selectedCategory
                                ? const Icon(Icons.auto_awesome, color: Color(0xFF00857A))
                                : null,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: _categories.map((category) {
                        final isAISuggested = _aiSuggestedCategory == category['id'];
                        return DropdownMenuItem<String>(
                          value: category['id'] as String,
                          child: Row(
                            children: [
                              Icon(category['icon'] as IconData, size: 20),
                              const SizedBox(width: 8),
                              Text(category['name'] as String),
                              if (isAISuggested) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF00857A)),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date, Time & Location Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00857A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on, color: Color(0xFF00857A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Date, Time & Location',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.calendar_today),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              child: Text(
                                _selectedDate != null
                                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                    : 'Select date',
                                style: TextStyle(
                                  color: _selectedDate != null ? Colors.black : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Time',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.access_time),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              child: Text(
                                _selectedTime != null
                                    ? _selectedTime!.format(context)
                                    : 'Select time',
                                style: TextStyle(
                                  color: _selectedTime != null ? Colors.black : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tower,
                            decoration: InputDecoration(
                              labelText: 'Tower Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.business),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _room,
                            decoration: InputDecoration(
                              labelText: 'Room Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.door_front_door),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contactNumber,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Contact Number',
                        hintText: 'Leave empty to use profile number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                        helperText: 'Optional: Will use your profile phone number if empty',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00857A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Submit Report',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
