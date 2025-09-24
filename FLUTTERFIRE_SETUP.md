# FlutterFire Configuration Setup

## Prerequisites Check

First, let's verify you have the necessary tools installed:

### 1. Check Firebase CLI
```powershell
firebase --version
```
If not installed:
```powershell
npm install -g firebase-tools
```

### 2. Check FlutterFire CLI
```powershell
dart pub global list
```
Look for `flutterfire_cli` in the output. If not installed:
```powershell
dart pub global activate flutterfire_cli
```

### 3. Login to Firebase
```powershell
firebase login
```

## Configure FlutterFire

### Step 1: Run FlutterFire Configure
Navigate to your project root and run:
```powershell
cd "e:\us workspace\3rddatabaseapp\donation_swap\mydonation-swapapp"
flutterfire configure
```

### Step 2: Select Options
When prompted:
1. **Select Firebase project**: Choose the project you created in Firebase Console
2. **Select platforms**: Choose all platforms you need (android, ios, web)
3. **Android app ID**: Should auto-detect `com.example.donationapplocal`
4. **iOS bundle ID**: Should auto-detect from your iOS project
5. **Web app ID**: Will be created automatically

### Step 3: Generated Files
FlutterFire will create/update:
- `firebase_options.dart` - Contains your Firebase configuration
- `android/app/google-services.json` - Android configuration
- `ios/Runner/GoogleService-Info.plist` - iOS configuration

## Test Firebase Connection

### Step 1: Run the App
```powershell
flutter run
```

### Step 2: Check Firebase Connection
The app should now connect to your real Firebase project instead of using test data.

### Step 3: Test Features
1. **Authentication**: Try signing up/in with email
2. **Firestore**: Create a post and see it in Firebase Console
3. **Storage**: Try uploading an image
4. **Cloud Messaging**: Test notifications (if implemented)

## Troubleshooting

### Common Issues:
1. **"No Firebase project found"**: Make sure you're logged in with `firebase login`
2. **"FlutterFire command not found"**: Run `dart pub global activate flutterfire_cli`
3. **Build errors**: Make sure `google-services.json` is in `android/app/`
4. **iOS issues**: Ensure `GoogleService-Info.plist` is properly added to Xcode project

### Debug Steps:
```powershell
# Check Flutter doctor
flutter doctor

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Deploy Firebase Rules and Functions

### Deploy Firestore Rules
```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

### Deploy Storage Rules
```powershell
firebase deploy --only storage
```

### Deploy Cloud Functions (after Node.js fix)
```powershell
cd functions
npm run build
cd ..
firebase deploy --only functions
```

## Verify in Firebase Console

After setup, check in Firebase Console:
1. **Authentication**: Users should appear as they sign up
2. **Firestore**: Documents should be created when users interact with app
3. **Storage**: Files should appear when users upload images
4. **Functions**: Should show deployed functions (after deployment)

Let me know if you encounter any issues during this setup!