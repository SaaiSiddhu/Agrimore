import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dialog_helper.dart';
import 'snackbar_helper.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();
  
  // Pick single image from gallery
  static Future<File?> pickImageFromGallery(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to pick image: $e');
      return null;
    }
  }
  
  // Pick single image from camera
  static Future<File?> pickImageFromCamera(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to capture image: $e');
      return null;
    }
  }
  
  // Pick multiple images from gallery
  static Future<List<File>?> pickMultipleImages(
    BuildContext context, {
    int maxImages = 5,
  }) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (images.isEmpty) return null;
      
      if (images.length > maxImages) {
        SnackbarHelper.showWarning(
          context,
          'You can only select up to $maxImages images',
        );
        return images.take(maxImages).map((xFile) => File(xFile.path)).toList();
      }
      
      return images.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to pick images: $e');
      return null;
    }
  }
  
  // Show image source selection dialog
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    final source = await DialogHelper.showChoice(
      context,
      title: 'Select Image Source',
      options: ['Camera', 'Gallery'],
    );
    
    if (source == null) return null;
    
    if (source == 0) {
      return await pickImageFromCamera(context);
    } else {
      return await pickImageFromGallery(context);
    }
  }
  
  // Pick image with source selection
  static Future<File?> pickImage(BuildContext context) async {
    return await showImageSourceDialog(context);
  }
  
  // Get image size
  static Future<Size?> getImageSize(File imageFile) async {
    try {
      final image = Image.file(imageFile);
      final completer = image.image.resolve(const ImageConfiguration());
      
      Size? size;
      completer.addListener(
        ImageStreamListener((info, _) {
          size = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        }),
      );
      
      return size;
    } catch (e) {
      return null;
    }
  }
  
  // Validate image file
  static bool validateImage(File imageFile, BuildContext context) {
    // Check if file exists
    if (!imageFile.existsSync()) {
      SnackbarHelper.showError(context, 'Image file does not exist');
      return false;
    }
    
    // Check file size (max 5MB)
    final fileSizeInBytes = imageFile.lengthSync();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    
    if (fileSizeInMB > 5) {
      SnackbarHelper.showError(
        context,
        'Image size should be less than 5MB',
      );
      return false;
    }
    
    return true;
  }
}
