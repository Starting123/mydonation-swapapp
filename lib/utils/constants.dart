class AppConstants {
  // Firebase Cloud Functions base URL
  // Replace with your actual project URL
  static const String cloudFunctionsBaseUrl = 
      'https://your-region-your-project-id.cloudfunctions.net';

  // Post categories
  static const List<String> postCategories = [
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

  // Item conditions
  static const List<String> itemConditions = [
    'Excellent',
    'Very Good',
    'Good',
    'Fair',
    'Poor'
  ];

  // Post expiry limits
  static const int minExpiryDays = 1;
  static const int maxExpiryDays = 7;

  // Image upload limits
  static const int maxImagesPerPost = 5;
  static const int maxImageSizeMB = 5;
  static const int imageQuality = 85;
  static const int maxImageDimension = 1024;

  // Validation constants
  static const int minTitleLength = 3;
  static const int maxTitleLength = 100;
  static const int minDescriptionLength = 10;
  static const int maxDescriptionLength = 1000;
  static const int minPasswordLength = 6;
  static const int minNameLength = 2;

  // Error messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String unknownError = 'An unknown error occurred. Please try again.';
  static const String authenticationError = 'Authentication failed. Please login again.';
  static const String permissionError = 'You don\'t have permission to perform this action.';
  static const String verificationRequired = 'ID verification is required to create posts.';

  // Success messages
  static const String postCreatedSuccess = 'Post created successfully!';
  static const String postUpdatedSuccess = 'Post updated successfully!';
  static const String postDeletedSuccess = 'Post deleted successfully!';
  static const String idSubmittedSuccess = 'ID submitted successfully! Verification is pending.';
  static const String signupSuccess = 'Account created successfully!';
  static const String loginSuccess = 'Welcome back!';

  // Notification channels
  static const String notificationChannelId = 'donation_swap_channel';
  static const String notificationChannelName = 'Donation Swap Notifications';
  static const String notificationChannelDescription = 'Notifications for donation swap app';

  // Colors (Material Design)
  static const int primaryColorValue = 0xFF4CAF50; // Green
  static const int secondaryColorValue = 0xFF2196F3; // Blue
  static const int errorColorValue = 0xFFF44336; // Red
  static const int warningColorValue = 0xFFFF9800; // Orange
  static const int successColorValue = 0xFF4CAF50; // Green
}