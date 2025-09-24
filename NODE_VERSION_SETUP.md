# Node.js Version Setup for Firebase Functions

## Issue
Your current Node.js version (v24.6.0) is incompatible with Firebase Functions, which requires Node.js 18.

## Solutions

### Option 1: Use Node Version Manager (Recommended)

#### Install NVM for Windows:
1. Download NVM for Windows from: https://github.com/coreybutler/nvm-windows/releases
2. Install the downloaded .exe file

#### Switch to Node 18:
```powershell
# Install Node.js 18
nvm install 18.19.0

# Use Node.js 18
nvm use 18.19.0

# Verify the version
node --version
# Should show v18.19.0
```

### Option 2: Manual Node.js Installation
1. Go to https://nodejs.org/en/download/releases
2. Download Node.js 18.19.0 LTS for Windows
3. Install it (this will replace your current version)

### Option 3: Use Docker (Advanced)
```powershell
# Run Firebase Functions in Docker container
docker run -it -v "${PWD}:/workspace" -w /workspace node:18 /bin/bash
npm install
npm run build
```

## After Switching to Node 18

1. Clear npm cache:
```powershell
npm cache clean --force
```

2. Delete node_modules and reinstall:
```powershell
cd "e:\us workspace\3rddatabaseapp\donation_swap\mydonation-swapapp\functions"
Remove-Item -Recurse -Force node_modules
npm install
```

3. Build the functions:
```powershell
npm run build
```

## Verify Setup
```powershell
# Check Node version
node --version
# Should show v18.x.x

# Check if TypeScript compiles
cd "e:\us workspace\3rddatabaseapp\donation_swap\mydonation-swapapp\functions"
npm run build
# Should complete without errors
```

## Alternative: Skip Cloud Functions for Now
If you want to proceed with Firebase setup without Cloud Functions initially:

1. Set up Firebase project in console
2. Configure Flutter app with `flutterfire configure`
3. Test basic Firebase features (Auth, Firestore, Storage)
4. Deploy Cloud Functions later when Node.js is properly configured

Let me know which approach you'd like to take!