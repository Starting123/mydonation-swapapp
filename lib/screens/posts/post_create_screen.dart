import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/post_service.dart';
import '../../models/post_model.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  
  String _selectedCategory = 'Electronics';
  PostType _selectedType = PostType.give;
  String _selectedCondition = 'Excellent';
  int _expiryDays = 7;
  List<File> _selectedImages = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final List<String> _categories = [
    'Electronics',
    'Clothing',
    'Books',
    'Furniture',
    'Sports',
    'Toys',
    'Home & Garden',
    'Automotive',
    'Health & Beauty',
    'Other'
  ];

  final List<String> _conditions = [
    'Excellent',
    'Very Good',
    'Good',
    'Fair',
    'Poor'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles.map((file) => File(file.path)).toList();
      });
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')),
        );
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final storageService = StorageService();
        final postService = PostService();

        // Check if user is verified
        String verificationStatus = await authService.getUserVerificationStatus();
        if (verificationStatus != 'approved') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You must be verified to create posts'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Generate post ID
        String postId = DateTime.now().millisecondsSinceEpoch.toString();

        // Upload images
        List<String> imageUrls = await storageService.uploadPostImages(
          _selectedImages,
          authService.currentUser!.uid,
          postId,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress * 0.8; // 80% for image upload
            });
          },
        );

        setState(() {
          _uploadProgress = 0.9; // 90% for Firestore creation
        });

        // Create post model
        PostModel post = PostModel(
          id: postId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          type: _selectedType,
          condition: _selectedCondition,
          brand: _brandController.text.trim(),
          imageUrls: imageUrls,
          expiryDays: _expiryDays,
          userId: authService.currentUser!.uid,
          userName: authService.currentUser!.displayName ?? 'Unknown',
          userEmail: authService.currentUser!.email ?? '',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(days: _expiryDays)),
          isActive: true,
        );

        // Save to Firestore
        await postService.createPost(post);

        setState(() {
          _uploadProgress = 1.0;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post created successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create post: $e')),
          );
        }
      } finally {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'What are you sharing?',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    if (value.length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'Describe the item in detail...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    if (value.length < 10) {
                      return 'Description must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category and Type Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<PostType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: PostType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getTypeDisplayName(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Condition and Brand Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCondition,
                        decoration: const InputDecoration(
                          labelText: 'Condition *',
                          border: OutlineInputBorder(),
                        ),
                        items: _conditions.map((condition) {
                          return DropdownMenuItem(
                            value: condition,
                            child: Text(condition),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCondition = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Brand',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Expiry Days
                Row(
                  children: [
                    const Text('Expires in: ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Slider(
                        value: _expiryDays.toDouble(),
                        min: 1,
                        max: 7,
                        divisions: 6,
                        label: '$_expiryDays day${_expiryDays > 1 ? 's' : ''}',
                        onChanged: (value) {
                          setState(() {
                            _expiryDays = value.round();
                          });
                        },
                      ),
                    ),
                    Text('$_expiryDays day${_expiryDays > 1 ? 's' : ''}'),
                  ],
                ),
                const SizedBox(height: 16),

                // Images Section
                const Text(
                  'Images *',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: _selectedImages.isEmpty
                      ? GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                  Text('Tap to add images', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _selectedImages.length) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add, size: 32, color: Colors.grey),
                                  ),
                                ),
                              );
                            }
                            
                            return Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImages[index],
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
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
                const SizedBox(height: 24),

                // Upload Progress
                if (_isUploading) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    'Creating post... ${(_uploadProgress * 100).toInt()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                ],

                // Create Post Button
                ElevatedButton(
                  onPressed: _isUploading ? null : _createPost,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Post',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeDisplayName(PostType type) {
    switch (type) {
      case PostType.give:
        return 'Give Away';
      case PostType.request:
        return 'Request';
      case PostType.swap:
        return 'Swap';
    }
  }
}