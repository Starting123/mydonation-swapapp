# Donation Swap App - Firebase Setup Guide

This guide will help you set up your Flutter donation swap app with real Firebase data.

## Prerequisites

1. **Flutter SDK** (already installed)
2. **Node.js** (version 18 or higher)
3. **Firebase CLI** 
4. **A Google account** for Firebase Console access

## Step 1: Install Firebase CLI

If you encounter issues with global installation, use npx instead:

```bash
# Try global installation first
npm install -g firebase-tools

# If global installation fails, use npx for all firebase commands
npx firebase-tools --version
```

## Step 2: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `donation-swap-app` (or your preferred name)
4. Disable Google Analytics (optional for this project)
5. Click "Create project"

## Step 3: Enable Firebase Services

In your Firebase Console:

### Enable Authentication
1. Go to **Authentication** > **Sign-in method**
2. Enable **Email/Password** provider
3. Enable **Google** provider (optional)

### Enable Firestore Database
1. Go to **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (we'll deploy proper rules later)
4. Select your preferred location

### Enable Cloud Storage
1. Go to **Storage**
2. Click **Get started**
3. Choose **Start in test mode** (we'll deploy proper rules later)

### Enable Cloud Functions
1. Go to **Functions**
2. Click **Get started**
3. Choose your preferred location (same as Firestore)

## Step 4: Install Firebase CLI and Initialize Project

```bash
# In your project root directory
cd "e:\us workspace\3rddatabaseapp\donation_swap\mydonation-swapapp"

# Login to Firebase (this will open browser)
firebase login
# OR if using npx
npx firebase-tools login

# Initialize Firebase in your project
firebase init
# OR if using npx
npx firebase-tools init
```

During `firebase init`, select:
- ✅ Firestore
- ✅ Functions 
- ✅ Storage
- Choose your Firebase project
- Use existing files for Firestore rules and indexes
- For Functions, choose TypeScript and use existing code

## Step 5: Get Firebase Configuration

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Scroll down to "Your apps" section
3. Click **Add app** > **Android**
4. Register your app:
   - Package name: `com.example.donation_swap` (or from your pubspec.yaml)
   - Download `google-services.json`
   - Place it in: `android/app/google-services.json`

5. Click **Add app** > **iOS** 
   - Bundle ID: `com.example.donationSwap` (or from ios/Runner.xcodeproj)
   - Download `GoogleService-Info.plist`
   - Place it in: `ios/Runner/GoogleService-Info.plist`

## Step 6: Install FlutterFire CLI

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Generate Firebase options for Flutter
flutterfire configure
```

This will create `lib/firebase_options.dart` with your Firebase configuration.

## Step 7: Update Flutter Dependencies

Make sure your `pubspec.yaml` includes all necessary Firebase dependencies:

```bash
flutter pub get
```

## Step 8: Deploy Cloud Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Deploy functions
firebase deploy --only functions
# OR if using npx
npx firebase-tools deploy --only functions
```

## Step 9: Deploy Firestore Rules and Indexes

```bash
# Deploy security rules and indexes
firebase deploy --only firestore
# OR if using npx
npx firebase-tools deploy --only firestore
```

## Step 10: Deploy Storage Rules

```bash
# Deploy storage security rules
firebase deploy --only storage
# OR if using npx
npx firebase-tools deploy --only storage
```

## Step 11: Test Your App

1. Run your Flutter app:
   ```bash
   flutter run
   ```

2. Try creating an account and posting an item to test real data integration.

## Troubleshooting

### Common Issues:

1. **Firebase CLI not found**: Use `npx firebase-tools` instead of `firebase`

2. **Node.js version issues**: Make sure you're using Node.js 18 or 20

3. **Permission errors**: Run PowerShell as Administrator

4. **Build errors in functions**: 
   ```bash
   cd functions
   npm install
   npm run build
   ```

5. **Authentication not working**: Check that you've added the configuration files in the correct locations

## Testing with Emulators (Optional)

For testing without deploying to production:

```bash
# Start Firebase emulators
firebase emulators:start
```

This will start local emulators for Authentication, Firestore, Functions, and Storage.

## Production Deployment

Once everything is working, deploy all services:

```bash
firebase deploy
```

## Monitoring

- **Authentication**: Firebase Console > Authentication
- **Database**: Firebase Console > Firestore Database  
- **Functions**: Firebase Console > Functions
- **Storage**: Firebase Console > Storage
- **Logs**: `firebase functions:log`

## Next Steps

1. Set up proper security rules for production
2. Configure app-specific settings in Firebase Console
3. Set up monitoring and analytics
4. Configure push notifications
5. Test all app features with real data

Remember to never commit your Firebase configuration files to version control if they contain sensitive information.