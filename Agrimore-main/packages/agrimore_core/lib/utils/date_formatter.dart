import 'package:intl/intl.dart';

class DateFormatter {
  // Format date to 'dd MMM yyyy' (e.g., 25 Oct 2025)
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }
  
  // Format time to 'hh:mm a' (e.g., 02:30 PM)
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }
  
  // Format date and time (e.g., 25 Oct 2025, 02:30 PM)
  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
  
  // Format date to 'dd/MM/yyyy' (e.g., 25/10/2025)
  static String formatDateSlash(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
  
  // Format date to 'MMMM dd, yyyy' (e.g., October 25, 2025)
  static String formatDateLong(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }
  
  // Format to 'EEE, MMM dd' (e.g., Sat, Oct 25)
  static String formatDateShort(DateTime date) {
    return DateFormat('EEE, MMM dd').format(date);
  }
  
  // Format to 'EEEE' (e.g., Saturday)
  static String formatDayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }
  
  // Format to 'MMMM' (e.g., October)
  static String formatMonthName(DateTime date) {
    return DateFormat('MMMM').format(date);
  }
  
  // Format to 'yyyy' (e.g., 2025)
  static String formatYear(DateTime date) {
    return DateFormat('yyyy').format(date);
  }
  
  // Get relative time (e.g., "2 hours ago", "3 days ago")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
  
  // Get time ago in short format (e.g., "2h", "3d")
  static String getTimeAgoShort(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo';
    } else {
      return '${(difference.inDays / 365).floor()}y';
    }
  }
  
  // Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
  
  // Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
           date.month == yesterday.month &&
           date.day == yesterday.day;
  }
  
  // Check if date is this week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
           date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }
  
  // Get greeting based on time of day
  static String getGreeting() {
    final hour = DateTime.now().hour;
    
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }
  
  // Format duration (e.g., "2h 30m", "1d 5h")
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      return '$days${days == 1 ? 'day' : 'days'} $hours${hours == 1 ? 'hr' : 'hrs'}';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '$hours${hours == 1 ? 'hr' : 'hrs'} $minutes${minutes == 1 ? 'min' : 'mins'}';
    } else {
      final minutes = duration.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }
  
  // Parse string to DateTime
  static DateTime? parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }
  
  // Get estimated delivery date (business days)
  static DateTime getEstimatedDeliveryDate(int businessDays) {
    DateTime date = DateTime.now();
    int addedDays = 0;
    
    while (addedDays < businessDays) {
      date = date.add(const Duration(days: 1));
      // Skip weekends (Saturday = 6, Sunday = 7)
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        addedDays++;
      }
    }
    
    return date;
  }
  
  // Format delivery date range
  static String formatDeliveryDateRange(DateTime startDate, DateTime endDate) {
    final start = DateFormat('dd MMM').format(startDate);
    final end = DateFormat('dd MMM').format(endDate);
    return '$start - $end';
  }
  
  // Check if date is in future
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }
  
  // Check if date is in past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }
  
  // Get days until date
  static int getDaysUntil(DateTime date) {
    final now = DateTime.now();
    return date.difference(now).inDays;
  }
  
  // Get hours until date
  static int getHoursUntil(DateTime date) {
    final now = DateTime.now();
    return date.difference(now).inHours;
  }
}
