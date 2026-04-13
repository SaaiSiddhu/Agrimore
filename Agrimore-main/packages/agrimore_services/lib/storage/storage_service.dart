import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:agrimore_core/agrimore_core.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload single image
  Future<String> uploadImage(File file, String folderPath) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
      final Reference ref = _storage.ref().child('$folderPath/$fileName');

      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw StorageException('Failed to upload image: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to upload image: ${e.toString()}');
    }
  }

  // Upload image bytes (web-compatible)
  Future<String> uploadImageBytes(Uint8List bytes, String folderPath, String fileName) async {
    try {
      final Reference ref = _storage.ref().child('$folderPath/$fileName');

      final UploadTask uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw StorageException('Failed to upload image: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to upload image: ${e.toString()}');
    }
  }

  // Upload multiple images
  Future<List<String>> uploadMultipleImages(List<File> files, String folderPath) async {
    try {
      final List<String> downloadUrls = [];

      for (final file in files) {
        final url = await uploadImage(file, folderPath);
        downloadUrls.add(url);
      }

      return downloadUrls;
    } catch (e) {
      throw StorageException('Failed to upload images: ${e.toString()}');
    }
  }

  // Upload multiple image bytes (web-compatible)
  Future<List<String>> uploadMultipleImageBytes(List<Uint8List> bytesList, String folderPath) async {
    try {
      final List<String> downloadUrls = [];

      for (int i = 0; i < bytesList.length; i++) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await uploadImageBytes(bytesList[i], folderPath, fileName);
        downloadUrls.add(url);
      }

      return downloadUrls;
    } catch (e) {
      throw StorageException('Failed to upload images: ${e.toString()}');
    }
  }

  // Upload product image
  Future<String> uploadProductImage(File file, String productId) async {
    return await uploadImage(file, 'products/$productId');
  }

  // Upload multiple product images
  Future<List<String>> uploadProductImages(List<File> files, String productId) async {
    return await uploadMultipleImages(files, 'products/$productId');
  }

  // Upload user profile image
  Future<String> uploadUserProfileImage(File file, String userId) async {
    return await uploadImage(file, 'users/$userId/profile');
  }

  // Upload user profile image bytes (web-compatible)
  Future<String> uploadUserProfileImageBytes(Uint8List bytes, String userId, String fileName) async {
    return await uploadImageBytes(bytes, 'users/$userId/profile', fileName);
  }

  // Upload category image
  Future<String> uploadCategoryImage(File file, String categoryId) async {
    return await uploadImage(file, 'categories/$categoryId');
  }

  // Upload banner image
  Future<String> uploadBannerImage(File file) async {
    return await uploadImage(file, 'banners');
  }

  // Upload banner image bytes (web-compatible)
  Future<String> uploadBannerImageBytes(Uint8List bytes, String fileName) async {
    return await uploadImageBytes(bytes, 'banners', fileName);
  }

  // Delete image by URL
  Future<void> deleteImageByUrl(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      throw StorageException('Failed to delete image: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to delete image: ${e.toString()}');
    }
  }

  // Delete multiple images
  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    try {
      for (final url in imageUrls) {
        await deleteImageByUrl(url);
      }
    } catch (e) {
      throw StorageException('Failed to delete images: ${e.toString()}');
    }
  }

  // Delete folder
  Future<void> deleteFolder(String folderPath) async {
    try {
      final ListResult result = await _storage.ref().child(folderPath).listAll();

      for (final Reference ref in result.items) {
        await ref.delete();
      }

      for (final Reference ref in result.prefixes) {
        await deleteFolder(ref.fullPath);
      }
    } on FirebaseException catch (e) {
      throw StorageException('Failed to delete folder: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to delete folder: ${e.toString()}');
    }
  }

  // Get download URL
  Future<String> getDownloadUrl(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw StorageException('Failed to get download URL: ${e.message}');
    } catch (e) {
      throw StorageException('Failed to get download URL: ${e.toString()}');
    }
  }

  // Check if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      await ref.getDownloadURL();
      return true;
    } catch (e) {
      return false;
    }
  }
}
