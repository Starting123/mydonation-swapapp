# Donation Swap Flutter App

A comprehensive Flutter application for donation and item sharing with Firebase backend integration.

## Features

### Authentication & Verification
- **Email/Password Authentication** using Firebase Auth
- **ID Verification System** with image upload to Firebase Storage
- **Role-based Access Control** (user/admin roles)
- **Secure Document Upload** with progress tracking

### Post Management
- **Create Posts** with multiple images, categorization, and expiry settings
- **Post Types**: Give away, Request, Swap
- **Form Validation** with expiry days limit (1-7 days)
- **Image Upload** with progress tracking and Firebase Storage integration
- **Real-time Updates** using Firestore streams

### Admin Panel (Cloud Functions)
- **Pending Verification Management** with secure image viewing
- **Approval/Rejection System** with audit logging
- **Role-based Security** ensuring only admins can access verification endpoints
- **Audit Trail** for all verification actions

## Architecture

### Flutter App Structure
```
lib/
├── main.dart                 # App entry point with Firebase initialization
├── models/                   # Data models (PostModel, UserModel)
├── screens/
│   ├── auth/                # Authentication screens
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── verify_id_screen.dart
│   └── posts/               # Post-related screens
│       ├── home_screen.dart
│       └── post_create_screen.dart
├── services/                # Business logic and API services
│   ├── auth_service.dart
│   ├── storage_service.dart
│   ├── post_service.dart
│   ├── notification_service.dart
│   └── cloud_function_service.dart
├── widgets/                 # Reusable UI components
│   └── common_widgets.dart
└── utils/                   # Constants and utilities
    └── constants.dart
```

### Firebase Cloud Functions (Node.js)
```
functions/
├── src/
│   └── index.ts            # Cloud Functions implementation
├── package.json
└── tsconfig.json
```

## Dependencies

### Flutter Dependencies
- **firebase_core**: ^2.24.2 - Firebase core functionality
- **firebase_auth**: ^4.15.3 - Authentication services
- **cloud_firestore**: ^4.13.6 - NoSQL database
- **firebase_storage**: ^11.6.0 - File storage
- **firebase_messaging**: ^14.7.10 - Push notifications
- **provider**: ^6.1.1 - State management
- **dio**: ^5.4.0 - HTTP client for API calls
- **cached_network_image**: ^3.3.1 - Optimized image loading
- **image_picker**: ^1.0.7 - Camera/gallery image selection
- **flutter_local_notifications**: ^17.0.0 - Local notifications

### Firebase Functions Dependencies
- **firebase-admin**: ^11.8.0 - Admin SDK
- **firebase-functions**: ^4.3.1 - Cloud Functions runtime

## Setup Instructions

### 1. Firebase Project Setup
1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable the following services:
   - **Authentication** (Email/Password provider)
   - **Cloud Firestore** (Database)
   - **Storage** (File storage)
   - **Cloud Functions** (Server-side logic)
   - **Cloud Messaging** (Push notifications)

### 2. Firebase Configuration
1. Add your Firebase configuration files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
   - Web: Update `web/index.html` with Firebase config

### 3. Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null && 
        resource.data.role == 'admin' && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Posts are readable by all authenticated users
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        request.auth.uid == resource.data.userId &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.idVerified == 'approved';
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    
    // Verification requests - admin only
    match /verification_requests/{requestId} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Audit logs - admin only
    match /verification_audit/{auditId} {
      allow read: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 4. Firebase Storage Security Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // ID verification images - user can upload, admin can read
    match /id_verifications/{userId}/{filename} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == 'admin'
      );
    }
    
    // Post images - user can upload/delete their own, everyone can read
    match /post_images/{userId}/{postId}/{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. Cloud Functions Setup
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Navigate to functions directory: `cd functions`
4. Install dependencies: `npm install`
5. Deploy functions: `firebase deploy --only functions`

### 6. Update Configuration
1. Update `cloud_function_service.dart` with your Firebase project URL
2. Update `constants.dart` with your project-specific values

## API Endpoints (Cloud Functions)

### Authentication Required
All endpoints require Firebase Authentication token in the Authorization header.

### Admin Endpoints
- **`submitIdForVerification`**: Submit ID image for verification
- **`getPendingVerifications`**: Get list of pending ID verifications (admin only)
- **`updateVerificationStatus`**: Approve/reject ID verification (admin only)
- **`getVerificationAuditLog`**: Get audit log of verification actions (admin only)
- **`getSignedImageUrl`**: Get secure signed URL for ID images (admin only)

## Data Models

### User Document (`users` collection)
```json
{
  "uid": "string",
  "fullName": "string",
  "email": "string",
  "idVerified": "not_submitted|pending|approved|rejected",
  "role": "user|admin",
  "idImageUrl": "string?",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Post Document (`posts` collection)
```json
{
  "id": "string",
  "title": "string",
  "description": "string",
  "category": "string",
  "type": "give|request|swap",
  "condition": "string",
  "brand": "string",
  "imageUrls": ["string"],
  "expiryDays": "number (1-7)",
  "userId": "string",
  "userName": "string",
  "userEmail": "string",
  "createdAt": "timestamp",
  "expiresAt": "timestamp",
  "isActive": "boolean"
}
```

## Security Features

### ID Verification Process
1. User uploads ID image to Firebase Storage
2. Cloud Function sets verification status to "pending"
3. Admin reviews ID through secure signed URLs
4. Admin approves/rejects with audit logging
5. User receives status update

### Role-Based Access Control
- **Users**: Can create posts only if ID verified
- **Admins**: Can manage ID verifications and view audit logs
- **Security Rules**: Enforced at database and storage levels

### Data Privacy
- ID images are stored securely with restricted access
- Only admins can view verification images through signed URLs
- All verification actions are logged for audit purposes

## Running the App

### Development
1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Set up Firebase configuration files
4. Run `flutter run` to start the app

### Production Deployment
1. Build the app: `flutter build apk` or `flutter build ios`
2. Deploy Cloud Functions: `firebase deploy --only functions`
3. Configure app signing and release

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.