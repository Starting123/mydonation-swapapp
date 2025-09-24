# Donation Swap App - Deployment Guide

This comprehensive guide covers all aspects of deploying the Flutter Donation Swap application with Firebase backend to production.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Firebase Project Setup](#firebase-project-setup)
3. [Cloud Functions Deployment](#cloud-functions-deployment)
4. [Firestore Database Setup](#firestore-database-setup)
5. [Firebase Storage Configuration](#firebase-storage-configuration)
6. [Firebase Cloud Messaging (FCM) Setup](#firebase-cloud-messaging-fcm-setup)
7. [Authentication Providers Configuration](#authentication-providers-configuration)
8. [Flutter App Build and Release](#flutter-app-build-and-release)
9. [CI/CD Pipeline Setup](#cicd-pipeline-setup)
10. [Monitoring and Analytics](#monitoring-and-analytics)
11. [Security Considerations](#security-considerations)
12. [Troubleshooting](#troubleshooting)

## Prerequisites

Before starting the deployment process, ensure you have the following:

- **Flutter SDK** (version 3.16.0 or later)
- **Firebase CLI** installed and configured
- **Node.js** (version 18 or later) for Cloud Functions
- **Android Studio** with Android SDK for Android builds
- **Xcode** (macOS only) for iOS builds
- **Git** for version control
- **Firebase Console** access with billing enabled
- **Google Play Console** account (for Android publishing)
- **Apple Developer** account (for iOS publishing)

### Install Required Tools

```bash
# Install Flutter
# Follow instructions at https://flutter.dev/docs/get-started/install

# Install Firebase CLI
npm install -g firebase-tools

# Install Node.js dependencies for Cloud Functions
cd functions
npm install

# Verify installations
flutter doctor
firebase --version
node --version
```

## Firebase Project Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `donation-swap-app`
4. Enable Google Analytics (recommended)
5. Select or create Analytics account
6. Click "Create project"

### 2. Enable Required Firebase Services

In the Firebase Console, enable the following services:

- **Authentication**
- **Firestore Database**
- **Cloud Storage**
- **Cloud Functions**
- **Cloud Messaging**
- **Analytics** (optional but recommended)
- **Performance Monitoring** (optional)
- **Crashlytics** (optional)

### 3. Configure Firebase for Flutter

```bash
# Login to Firebase
firebase login

# Initialize Firebase in your Flutter project
firebase init

# Select the following services:
# - Firestore
# - Functions
# - Storage
# - Hosting (optional)

# Add Firebase to Flutter apps
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add firebase_messaging

# Configure FlutterFire
dart pub global activate flutterfire_cli
flutterfire configure
```

## Cloud Functions Deployment

### 1. Prepare Cloud Functions

```bash
cd functions
npm install
npm run build
```

### 2. Deploy Cloud Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:sendMessageNotification

# View function logs
firebase functions:log
```

### 3. Set Environment Variables

```bash
# Set configuration for Cloud Functions
firebase functions:config:set someservice.key="THE API KEY"
firebase functions:config:set someservice.id="THE CLIENT ID"

# Deploy updated configuration
firebase deploy --only functions
```

## Firestore Database Setup

### 1. Create Firestore Database

1. Go to Firebase Console → Firestore Database
2. Click "Create database"
3. Choose "Start in production mode" for production
4. Select database location (choose closest to your users)

### 2. Configure Security Rules

Create/update `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Posts are readable by all authenticated users
    // Only the owner can write/update/delete
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                   request.auth.uid == request.resource.data.userId;
      allow update, delete: if request.auth != null && 
                           request.auth.uid == resource.data.userId;
    }
    
    // Chats - only participants can access
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
                        request.auth.uid in resource.data.participants;
    }
    
    // Messages - only chat participants can access
    match /chats/{chatId}/messages/{messageId} {
      allow read, write: if request.auth != null && 
                        request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
    }
    
    // Notifications - users can only read their own
    match /notifications/{notificationId} {
      allow read: if request.auth != null && 
                 request.auth.uid == resource.data.userId;
      allow create: if request.auth != null;
    }
    
    // Reputation logs - read only for users
    match /reputation_logs/{logId} {
      allow read: if request.auth != null;
    }
    
    // User reputation - readable by all, writable by Cloud Functions only
    match /user_reputation/{userId} {
      allow read: if request.auth != null;
    }
    
    // Feedback - users can create, read their own
    match /feedbacks/{feedbackId} {
      allow read: if request.auth != null && 
                 (request.auth.uid == resource.data.fromUserId || 
                  request.auth.uid == resource.data.toUserId);
      allow create: if request.auth != null && 
                   request.auth.uid == request.resource.data.fromUserId;
    }
    
    // Abuse reports - users can create
    match /abuse_reports/{reportId} {
      allow create: if request.auth != null && 
                   request.auth.uid == request.resource.data.reportedBy;
    }
    
    // User alerts - users can manage their own
    match /user_alerts/{alertId} {
      allow read, write: if request.auth != null && 
                        request.auth.uid == resource.data.userId;
    }
  }
}
```

Deploy rules:

```bash
firebase deploy --only firestore:rules
```

### 3. Create Indexes

Create/update `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "isActive", "order": "ASCENDING"},
        {"fieldPath": "expiresAt", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION", 
      "fields": [
        {"fieldPath": "category", "order": "ASCENDING"},
        {"fieldPath": "isActive", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "type", "order": "ASCENDING"},
        {"fieldPath": "isActive", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "chatId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "user_reputation",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "totalScore", "order": "DESCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy indexes:

```bash
firebase deploy --only firestore:indexes
```

## Firebase Storage Configuration

### 1. Configure Storage Rules

Create/update `storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Images can be uploaded by authenticated users
    match /post_images/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024  // 5MB limit
                   && request.resource.contentType.matches('image/.*');
    }
    
    // ID verification images - users can only access their own
    match /id_verification/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null 
                        && request.auth.uid == userId
                        && request.resource.size < 10 * 1024 * 1024  // 10MB limit
                        && request.resource.contentType.matches('image/.*');
    }
    
    // Profile pictures
    match /profile_pictures/{userId} {
      allow read: if true;
      allow write: if request.auth != null 
                   && request.auth.uid == userId
                   && request.resource.size < 2 * 1024 * 1024  // 2MB limit
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

Deploy storage rules:

```bash
firebase deploy --only storage
```

## Firebase Cloud Messaging (FCM) Setup

### 1. Configure FCM for Android

1. In Firebase Console → Project Settings → Cloud Messaging
2. Upload your server key to Firebase
3. Add the `google-services.json` file to `android/app/`

### 2. Configure FCM for iOS

1. Upload your APNs authentication key or certificate
2. Add the `GoogleService-Info.plist` file to `ios/Runner/`

### 3. Test Push Notifications

```bash
# Test notification via Firebase Console
# Go to Cloud Messaging → Send test message
```

## Authentication Providers Configuration

### 1. Enable Email/Password Authentication

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable "Email/Password"
3. Optionally enable "Email link (passwordless sign-in)"

### 2. Configure Google Sign-In

1. Enable "Google" provider
2. Set up OAuth consent screen in Google Cloud Console
3. Add SHA-1 fingerprints for Android

```bash
# Get SHA-1 fingerprint for debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Get SHA-1 fingerprint for release
keytool -list -v -keystore path/to/your/release-keystore.jks -alias your-alias
```

### 3. Configure Facebook Sign-In (Optional)

1. Create Facebook App in Facebook Developers Console
2. Enable Facebook provider in Firebase
3. Add Facebook App ID and secret
4. Configure Facebook SDK in Flutter app

### 4. Configure Apple Sign-In (iOS)

1. Enable Apple provider in Firebase
2. Configure Apple Developer account
3. Add Apple Sign-In capability to iOS app

## Flutter App Build and Release

### 1. Configure App Signing

#### Android Signing

Create `android/key.properties`:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=path/to/your/keystore.jks
```

Update `android/app/build.gradle`:

```gradle
android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### iOS Signing

Configure in Xcode:
1. Open `ios/Runner.xcworkspace`
2. Select Runner target
3. Configure signing under "Signing & Capabilities"

### 2. Build Release Versions

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

### 3. Test Release Builds

```bash
# Test Android APK
flutter install --release

# Test iOS build
flutter run --release
```

## Publishing to App Stores

### 1. Google Play Store

1. Create app in Google Play Console
2. Upload App Bundle (AAB file)
3. Configure store listing
4. Set up app signing
5. Submit for review

```bash
# Upload using fastlane (optional)
cd android
fastlane supply
```

### 2. Apple App Store

1. Create app in App Store Connect
2. Archive and upload via Xcode or Application Loader
3. Configure app metadata
4. Submit for review

```bash
# Upload using fastlane (optional)
cd ios
fastlane deliver
```

## CI/CD Pipeline Setup

### 1. GitHub Actions Configuration

The workflow file is already created at `.github/workflows/flutter_ci.yml`

### 2. Required Secrets

Add these secrets to your GitHub repository:

- `FIREBASE_TOKEN`: Firebase CLI token for deployment
- `ANDROID_KEYSTORE`: Base64 encoded Android keystore
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password
- `IOS_CERTIFICATE`: iOS distribution certificate
- `IOS_PROVISIONING_PROFILE`: iOS provisioning profile
- `SLACK_WEBHOOK`: Slack webhook URL for notifications

```bash
# Generate Firebase token
firebase login:ci

# Encode Android keystore
base64 -i your-keystore.jks
```

### 3. Automated Deployment

The pipeline automatically:
- Runs tests on every push
- Builds APK/AAB for Android
- Deploys Cloud Functions
- Updates Firestore rules
- Sends notifications

## Monitoring and Analytics

### 1. Firebase Analytics

```dart
// Track custom events
FirebaseAnalytics.instance.logEvent(
  name: 'post_created',
  parameters: {
    'category': 'Electronics',
    'type': 'give',
  },
);
```

### 2. Crashlytics

```dart
// Report custom errors
FirebaseCrashlytics.instance.recordError(
  error,
  stackTrace,
  reason: 'Custom error description',
);
```

### 3. Performance Monitoring

```dart
// Track custom traces
final trace = FirebasePerformance.instance.newTrace('post_load_time');
trace.start();
// ... your code
trace.stop();
```

## Security Considerations

### 1. API Key Security

- Use different Firebase projects for development and production
- Restrict API keys to specific platforms
- Enable App Check for additional security

### 2. Data Validation

- Implement server-side validation in Cloud Functions
- Use Firestore security rules as second layer
- Sanitize user inputs

### 3. User Privacy

- Implement proper data retention policies
- Add privacy controls in app settings
- Comply with GDPR/CCPA requirements

### 4. Security Rules Testing

```bash
# Test Firestore rules
firebase emulators:start --only firestore
# Run your tests against the emulator
```

## Troubleshooting

### Common Issues

#### 1. Build Failures

```bash
# Clear Flutter cache
flutter clean
flutter pub get
flutter pub upgrade

# Clear gradle cache (Android)
cd android
./gradlew clean

# Clear derived data (iOS)
rm -rf ~/Library/Developer/Xcode/DerivedData
```

#### 2. Firebase Connection Issues

```bash
# Re-configure FlutterFire
flutterfire configure

# Check Firebase configuration
flutter pub run firebase_tools:check
```

#### 3. Cloud Functions Issues

```bash
# Check function logs
firebase functions:log

# Local testing
firebase emulators:start --only functions
```

#### 4. Performance Issues

- Enable code obfuscation for release builds
- Optimize images and assets
- Use lazy loading for lists
- Implement proper state management

### Monitoring Commands

```bash
# Monitor app performance
flutter run --profile

# Analyze bundle size
flutter build apk --analyze-size

# Check for unused dependencies
flutter pub deps
```

## Environment Management

### Development Environment

```bash
# Use development Firebase project
flutterfire configure --project=donation-swap-dev
```

### Staging Environment

```bash
# Use staging Firebase project
flutterfire configure --project=donation-swap-staging
```

### Production Environment

```bash
# Use production Firebase project
flutterfire configure --project=donation-swap-prod
```

## Maintenance Tasks

### Regular Tasks

1. **Monitor Error Rates**: Check Crashlytics weekly
2. **Update Dependencies**: Monthly security updates
3. **Performance Review**: Quarterly performance analysis
4. **User Feedback**: Regular app store review monitoring
5. **Security Audit**: Annual security review

### Backup Procedures

```bash
# Export Firestore data
gcloud firestore export gs://your-backup-bucket/backup-$(date +%Y%m%d)

# Backup Cloud Functions
git tag release-$(date +%Y%m%d)
git push origin --tags
```

## Support and Documentation

- **Flutter Documentation**: https://flutter.dev/docs
- **Firebase Documentation**: https://firebase.google.com/docs
- **GitHub Issues**: Create issues for bugs and feature requests
- **Team Communication**: Use designated Slack channels

---

This deployment guide provides a comprehensive overview of deploying the Donation Swap Flutter application. For specific questions or issues not covered here, please refer to the official documentation or create an issue in the project repository.