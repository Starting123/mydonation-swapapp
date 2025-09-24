# Firebase Console Setup Guide

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project" or "Create a project"
3. Enter project name: `donation-swap-app` (or your preferred name)
4. Enable Google Analytics (recommended)
5. Choose or create a Google Analytics account
6. Click "Create project"

## Step 2: Enable Authentication

1. In Firebase Console, go to **Authentication** → **Get started**
2. Go to **Sign-in method** tab
3. Enable the following providers:
   - **Email/Password**: Enable
   - **Google**: Enable (configure OAuth consent screen if needed)
   - **Anonymous**: Enable (for guest access)

### Configure OAuth Consent Screen (for Google Sign-in):
1. Go to [Google Console](https://console.developers.google.com/)
2. Select your project
3. Go to **APIs & Services** → **OAuth consent screen**
4. Fill in required fields:
   - App name: `Donation Swap`
   - User support email: Your email
   - Developer contact information: Your email

## Step 3: Enable Firestore Database

1. Go to **Firestore Database** → **Create database**
2. Choose **Start in production mode** (we have security rules ready)
3. Select database location (choose closest to your users)
4. Click **Done**

## Step 4: Enable Storage

1. Go to **Storage** → **Get started**
2. Choose **Start in production mode**
3. Select storage location (same as Firestore for consistency)
4. Click **Done**

## Step 5: Enable Cloud Messaging (FCM)

1. Go to **Cloud Messaging**
2. If prompted, enable the Cloud Messaging API

## Step 6: Add Android App

1. Go to **Project settings** (gear icon) → **General** tab
2. Click **Add app** → **Android**
3. Fill in:
   - **Android package name**: `com.example.donationapplocal` (from your android/app/build.gradle)
   - **App nickname**: `Donation Swap Android`
   - **Debug signing certificate SHA-1**: (optional for now)
4. Click **Register app**
5. Download `google-services.json`
6. Place it in `android/app/` directory (replace existing if any)

## Step 7: Add iOS App (if needed)

1. Click **Add app** → **iOS**
2. Fill in:
   - **iOS bundle ID**: Check your `ios/Runner/Info.plist` for bundle identifier
   - **App nickname**: `Donation Swap iOS`
3. Download `GoogleService-Info.plist`
4. Add it to `ios/Runner/` directory

## Step 8: Get Web Configuration (if needed)

1. Click **Add app** → **Web**
2. Fill in:
   - **App nickname**: `Donation Swap Web`
3. Copy the Firebase config object (you'll need this later)

## Step 9: Service Account (for Admin SDK)

1. Go to **Project settings** → **Service accounts** tab
2. Click **Generate new private key**
3. Download the JSON file (keep it secure!)
4. This will be used for Cloud Functions admin operations

## Important Notes:

### Security Rules
- Your Firestore and Storage rules are already configured in the project
- They will be deployed using Firebase CLI later

### API Keys
- The downloaded configuration files contain your API keys
- These are safe to include in your app (they're designed to be public)
- Security is enforced by Firebase rules, not by hiding keys

### Billing
- Firebase has a generous free tier
- For production apps, consider upgrading to Blaze plan for:
  - Cloud Functions
  - Extended database operations
  - More storage and bandwidth

## Next Steps After Console Setup:

1. Download and place configuration files in your project
2. Install Firebase CLI: `npm install -g firebase-tools`
3. Login to Firebase: `firebase login`
4. Initialize project: `firebase init`
5. Run `flutterfire configure` to generate Flutter configuration

Let me know when you've completed the Firebase Console setup!