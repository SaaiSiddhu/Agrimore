import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({Key? key}) : super(key: key);

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final imageUrlController = TextEditingController();
  final actionUrlController = TextEditingController();

  String sendType = 'all';
  String notificationType = 'general';
  String? selectedUserId;
  String? selectedProductId;
  String? selectedOrderId;

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> orders = [];

  bool isLoading = false;
  bool isUploadingImage = false;
  bool isLoadingData = true;
  String? uploadedImageUrl;
  File? selectedImageFile;

  final Map<String, Map<String, String>> templates = {
    'new_product': {
      'title': 'New Product Launch!',
      'body': 'Check out our latest product - Amazing quality, great prices!',
    },
    'offer': {
      'title': 'Special Offer Just for You!',
      'body': 'Get huge discounts on your next purchase. Limited time only!',
    },
    'order_update': {
      'title': 'Order Update',
      'body': 'Your order has been updated. Check the app for details!',
    },
    'welcome': {
      'title': 'Welcome to Agrimore!',
      'body': 'Thank you for joining us. Start exploring our products now!',
    },
  };

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    loadData();
  }

  Future<void> loadData() async {
    setState(() => isLoadingData = true);
    try {
      await Future.wait([
        loadUsers(),
        loadProducts(),
        loadOrders(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingData = false);
      }
    }
  }

  Future<void> loadUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(100)
          .get();

      if (mounted) {
        setState(() {
          users = snapshot.docs
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['name'] ?? 'Unknown',
                  'email': data['email'] ?? '',
                  'phone': data['phone'] ?? '',
                };
              })
              .toList();
        });
        debugPrint('✅ Loaded ${users.length} users');
      }
    } catch (e) {
      debugPrint('❌ Error loading users: $e');
    }
  }

  Future<void> loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          products = snapshot.docs
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['name'] ?? 'Unknown Product',
                  'price': data['price'] ?? 0,
                  'imageUrl': data['imageUrl'] ??
                      (data['images'] != null && data['images'].isNotEmpty
                          ? data['images'][0]
                          : ''),
                };
              })
              .toList();
          products.sort((a, b) =>
              (a['name'] as String).compareTo(b['name'] as String));
        });
        debugPrint('✅ Loaded ${products.length} products');
      }
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
    }
  }

  Future<void> loadOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          orders = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final createdAt = data['createdAt'] is Timestamp
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.now();
                return {
                  'id': doc.id,
                  'orderNumber': data['orderNumber'] ?? 'Unknown',
                  'status': data['orderStatus'] ?? 'pending',
                  'total': data['total'] ?? 0,
                  'userId': data['userId'] ?? '',
                  'createdAt': createdAt,
                  'items': (data['items'] as List?)?.length ?? 0,
                };
              })
              .toList();
        });
        debugPrint('✅ Loaded ${orders.length} orders');
      }
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
    }
  }

  Future<void> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            uploadedImageUrl = image.path;
          } else {
            selectedImageFile = File(image.path);
          }
        });
        await uploadImage(image);
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to pick image');
      }
    }
  }

  Future<void> uploadImage(XFile image) async {
    setState(() => isUploadingImage = true);
    try {
      final String fileName =
          'notifications/${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      final Reference ref = FirebaseStorage.instance.ref().child(fileName);

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(image.path));
      }

      final String downloadUrl = await ref.getDownloadURL();
      setState(() {
        uploadedImageUrl = downloadUrl;
        imageUrlController.text = downloadUrl;
      });

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Image uploaded successfully!');
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to upload image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isUploadingImage = false);
      }
    }
  }

  void useTemplate(String templateKey) {
    final template = templates[templateKey]!;
    setState(() {
      titleController.text = template['title']!;
      bodyController.text = template['body']!;
    });
  }

  // ✅ COMPLETELY FIXED - Now properly formats actionUrl
  Future<void> sendNotification() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      debugPrint('🔧 Preparing notification data...');

      // ✅ FIXED: Properly format actionUrl
      String? actionUrl = actionUrlController.text.trim();
      
      // If actionUrl is not empty, format it correctly
      if (actionUrl != null && actionUrl.isNotEmpty) {
        // Remove leading/trailing slashes
        actionUrl = actionUrl.replaceAll(RegExp(r'^/+|/+$'), '');
        
        // If it's a full URL (starts with http/https), keep it as is
        // Otherwise, treat it as an internal route
        if (!actionUrl.startsWith('http://') && !actionUrl.startsWith('https://')) {
          // Internal route - ensure it starts with /
          actionUrl = '/$actionUrl';
        }
        
        debugPrint('📍 Formatted actionUrl: $actionUrl');
      } else {
        actionUrl = null;
      }

      final Map<String, dynamic> functionData = {
        'title': titleController.text.trim(),
        'body': bodyController.text.trim(),
        'imageUrl': uploadedImageUrl?.trim() ?? imageUrlController.text.trim() ?? '',
        'actionUrl': actionUrl,
        'type': notificationType,
      };

      // Add productId if product is selected
      if (selectedProductId != null) {
        functionData['productId'] = selectedProductId;
        // Auto-set actionUrl if not manually entered
        if (actionUrl == null || actionUrl.isEmpty) {
          functionData['actionUrl'] = '/product/$selectedProductId';
          debugPrint('📍 Auto-set product actionUrl: /product/$selectedProductId');
        }
      }

      debugPrint('📝 Function data prepared: $functionData');

      HttpsCallableResult result;

      if (sendType == 'all') {
        debugPrint('📢 Calling sendBroadcastNotification...');
        final callable = FirebaseFunctions.instance
            .httpsCallable('sendBroadcastNotification');
        result = await callable.call(functionData);
        debugPrint('✅ Broadcast result: ${result.data}');
      } else if (sendType == 'single') {
        if (selectedUserId == null) {
          if (mounted) {
            SnackbarHelper.showError(context, 'Please select a user');
          }
          setState(() => isLoading = false);
          return;
        }
        functionData['userId'] = selectedUserId;
        debugPrint('📬 Calling sendNotificationToUser for: $selectedUserId');
        final callable =
            FirebaseFunctions.instance.httpsCallable('sendNotificationToUser');
        result = await callable.call(functionData);
        debugPrint('✅ Single user result: ${result.data}');
      } else {
        throw Exception('Invalid send type');
      }

      // Log to notification history
      final historyData = {
        'title': titleController.text.trim(),
        'body': bodyController.text.trim(),
        'imageUrl': uploadedImageUrl?.trim() ?? imageUrlController.text.trim() ?? '',
        'actionUrl': actionUrl,
        'type': notificationType,
        'sendType': sendType,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      try {
        await FirebaseFirestore.instance
            .collection('notification_history')
            .add(historyData);
        debugPrint('✅ Logged to notification_history');
      } catch (e) {
        debugPrint('⚠️ Failed to log to history: $e');
      }

      if (mounted && result.data != null) {
        final successCount = result.data['successCount'] ?? 0;
        final failureCount = result.data['failureCount'] ?? 0;
        final message = result.data['message'] ?? 'Notification sent!';

        debugPrint('📊 Success: $successCount, Failed: $failureCount');

        if (mounted) {
          showSuccessDialog(
            'Notification Sent! ✅',
            '$message\n\nSuccess: $successCount\nFailed: $failureCount',
          );
        }

        _clearForm();
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Firebase Functions Error:');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      debugPrint('Details: ${e.details}');

      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _clearForm() {
    try {
      titleController.clear();
      bodyController.clear();
      imageUrlController.clear();
      actionUrlController.clear();
      setState(() {
        uploadedImageUrl = null;
        selectedImageFile = null;
        selectedUserId = null;
        selectedProductId = null;
        selectedOrderId = null;
        notificationType = 'general';
        sendType = 'all';
      });
      debugPrint('✅ Form cleared successfully');
    } catch (e) {
      debugPrint('⚠️ Error clearing form: $e');
    }
  }

  void showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Send Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Compose'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: tabController,
              children: [
                _buildComposeTab(),
                _buildHistoryTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }

  Widget _buildComposeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTypeCard(
                    'general',
                    Icons.notifications,
                    'General',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeCard(
                    'product',
                    Icons.shopping_bag,
                    'Product',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeCard(
                    'order',
                    Icons.local_shipping,
                    'Order',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeCard(
                    'offer',
                    Icons.local_offer,
                    'Offer',
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Quick Templates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: templates.keys
                  .map(
                    (key) => ActionChip(
                      label: Text(key.replaceAll('_', ' ').toUpperCase()),
                      onPressed: () => useTemplate(key),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      labelStyle: TextStyle(color: AppColors.primary),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),
            const Text(
              'Send To',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'all',
                  label: Text('All Users'),
                  icon: Icon(Icons.people),
                ),
                ButtonSegment(
                  value: 'single',
                  label: Text('Single User'),
                  icon: Icon(Icons.person),
                ),
              ],
              selected: {sendType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => sendType = newSelection.first);
              },
            ),
            const SizedBox(height: 24),
            if (sendType == 'single') _buildUserSelection(),
            const SizedBox(height: 24),
            if (notificationType == 'order') _buildOrderSelection(),
            const SizedBox(height: 24),
            if (notificationType == 'product') _buildProductSelection(),
            const SizedBox(height: 24),
            const Text(
              'Notification Title',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Enter a catchy title...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.title),
                counterText: '${titleController.text.length}/50',
              ),
              maxLength: 50,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter title';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 24),
            const Text(
              'Notification Message',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bodyController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Write your message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                counterText: '${bodyController.text.length}/200',
              ),
              maxLength: 200,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter message';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 24),
            const Text(
              'Notification Image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            uploadedImageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                uploadedImageUrl = null;
                                imageUrlController.clear();
                                selectedImageFile = null;
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Icon(Icons.cloud_upload,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Upload notification image',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: isUploadingImage ? null : pickImage,
                          icon: isUploadingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(isUploadingImage
                              ? 'Uploading...'
                              : 'Choose Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ✅ IMPROVED: Better helper text and examples
            const Text(
              'Action URL (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Examples: product/123, orders, profile, https://website.com',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: actionUrlController,
              decoration: InputDecoration(
                hintText: 'product/123 or https://yourwebsite.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.link),
                helperText: 'Where to navigate when notification is tapped',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : sendNotification,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 24),
                label: Text(
                  isLoading ? 'Sending...' : 'Send Notification',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(
    String type,
    IconData icon,
    String label,
    Color color,
  ) {
    final isSelected = notificationType == type;
    return InkWell(
      onTap: () => setState(() => notificationType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select User',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (users.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No users found',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: selectedUserId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.person),
              ),
              hint: const Text('Choose a user'),
              items: users
                  .map(
                    (user) => DropdownMenuItem<String>(
                      value: user['id'] as String,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user['email'] as String,
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => selectedUserId = value),
              validator: (value) {
                if (sendType == 'single' && value == null) {
                  return 'Please select a user';
                }
                return null;
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOrderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Order',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No orders found',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: selectedOrderId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.shopping_bag),
              ),
              hint: const Text('Choose an order'),
              items: orders
                  .map(
                    (order) => DropdownMenuItem<String>(
                      value: order['id'] as String,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${order['orderNumber']} (${order['status']})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '₹${order['total']} - ${order['items']} items',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => selectedOrderId = value),
            ),
          ),
      ],
    );
  }

  Widget _buildProductSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Product (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No products found',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: selectedProductId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.shopping_bag),
              ),
              hint: const Text('Choose a product'),
              items: products
                  .map(
                    (product) => DropdownMenuItem<String>(
                      value: product['id'] as String,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (product['imageUrl'] as String).isNotEmpty
                                ? Image.network(
                                    product['imageUrl'] as String,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildPlaceholderImage(),
                                  )
                                : _buildPlaceholderImage(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  product['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '₹${product['price']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => selectedProductId = value);
                if (value != null) {
                  final product = products.firstWhere((p) => p['id'] == value);
                  final imageUrl = product['imageUrl'] as String;
                  if (imageUrl.isNotEmpty) {
                    imageUrlController.text = imageUrl;
                    uploadedImageUrl = imageUrl;
                  }
                  // Auto-populate actionUrl
                  if (actionUrlController.text.trim().isEmpty) {
                    actionUrlController.text = 'product/$value';
                  }
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 40,
      height: 40,
      color: Colors.grey.shade300,
      child: const Icon(
        Icons.image_not_supported,
        size: 20,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notification_history')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data!.docs;

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No notification history',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif =
                notifications[index].data() as Map<String, dynamic>;
            final timestamp = notif['timestamp'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(notif['title'] ?? 'No title',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      notif['body'] ?? 'No message',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(timestamp),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
                trailing: Chip(
                  label: Text(notif['type'] ?? 'general'),
                  backgroundColor: _getTypeColor(notif['type'] ?? 'general'),
                  labelStyle:
                      const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return FutureBuilder<QuerySnapshot>(
      future:
          FirebaseFirestore.instance.collection('notification_history').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final total = snapshot.data!.docs.length;
        final Map<String, int> typeCount = {};

        for (var doc in snapshot.data!.docs) {
          final type =
              (doc.data() as Map<String, dynamic>)['type'] ?? 'general';
          typeCount[type] = (typeCount[type] ?? 0) + 1;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        color: Colors.white, size: 48),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Notifications',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          total.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Notifications by Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...typeCount.entries
                  .map(
                    (entry) {
                      final percentage = total > 0
                          ? ((entry.value / total) * 100).toStringAsFixed(1)
                          : '0.0';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getTypeColor(entry.key),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getTypeIcon(entry.key),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value:
                                        total > 0 ? entry.value / total : 0,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getTypeColor(entry.key),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  )
                  .toList(),
            ],
          ),
        );
      },
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'product':
        return Colors.green;
      case 'order':
        return Colors.orange;
      case 'offer':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'product':
        return Icons.shopping_bag;
      case 'order':
        return Icons.local_shipping;
      case 'offer':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    imageUrlController.dispose();
    actionUrlController.dispose();
    tabController.dispose();
    super.dispose();
  }
}
