import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'snackbar_helper.dart';

class UrlLauncherHelper {
  // Launch URL in browser
  static Future<void> launchWebUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SnackbarHelper.showError(context, 'Could not launch URL');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error launching URL: $e');
    }
  }
  
  // Launch email
  static Future<void> launchEmail(
    BuildContext context,
    String email, {
    String? subject,
    String? body,
  }) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          if (subject != null) 'subject': subject,
          if (body != null) 'body': body,
        },
      );
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        SnackbarHelper.showError(context, 'Could not launch email client');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error launching email: $e');
    }
  }
  
  // Launch phone call
  static Future<void> launchPhone(BuildContext context, String phoneNumber) async {
    try {
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        SnackbarHelper.showError(context, 'Could not launch phone dialer');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error launching phone: $e');
    }
  }
  
  // Launch SMS
  static Future<void> launchSMS(
    BuildContext context,
    String phoneNumber, {
    String? message,
  }) async {
    try {
      final uri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {
          if (message != null) 'body': message,
        },
      );
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        SnackbarHelper.showError(context, 'Could not launch SMS');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error launching SMS: $e');
    }
  }
  
  // Launch WhatsApp
  static Future<void> launchWhatsApp(
    BuildContext context,
    String phoneNumber, {
    String? message,
  }) async {
    try {
      final uri = Uri.parse(
        'https://wa.me/$phoneNumber${message != null ? '?text=${Uri.encodeComponent(message)}' : ''}',
      );
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SnackbarHelper.showError(context, 'WhatsApp is not installed');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error launching WhatsApp: $e');
    }
  }
  
  // Launch Google Maps with coordinates
  static Future<void> launchMaps(
    BuildContext context,
    double latitude,
    double longitude, {
    String? label,
  }) async {
    try {
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude${label != null ? '&query_place_id=$label' : ''}',
      );
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SnackbarHelper.showError(context, 'Could not launch maps');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error launching maps: $e');
    }
  }
  
  // Launch Google Maps directions
  static Future<void> launchMapsDirections(
    BuildContext context,
    double destLatitude,
    double destLongitude,
    String destinationLabel,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destLatitude,$destLongitude&destination_place_id=$destinationLabel',
      );
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SnackbarHelper.showError(context, 'Could not launch maps');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Error launching maps: $e');
    }
  }
  
  // Share text (using device share sheet)
  static Future<void> shareText(String text) async {
    // Note: This requires share_plus package
    // For now, we'll just show a message
    // You can integrate share_plus package later
  }
}
