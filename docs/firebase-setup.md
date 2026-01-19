# Firebase App Distribution Setup Guide for YourTurn

## Prerequisites
1. Firebase project created at https://console.firebase.google.com
2. Firebase CLI installed (`npm install -g firebase-tools`)
3. Codemagic account with access to your repository

## Step 1: Set Up Firebase Project

1. Go to https://console.firebase.google.com
2. Create a new project or select existing one
3. Add Android app:
   - Package name: `com.tendimensions.yourturn`
   - Download `google-services.json` (add to `android/app/` directory)
4. Add iOS app:
   - Bundle ID: `com.tendimensions.yourturn`
   - Download `GoogleService-Info.plist` (add to `ios/Runner/` directory)

## Step 2: Enable Firebase App Distribution

1. In Firebase Console, go to **App Distribution**
2. Click **Get Started**
3. Create tester groups:
   - `testers` - for production builds
   - `dev-testers` - for dev builds
4. Add testers' email addresses to groups

## Step 3: Get Firebase Token for Codemagic

Run in terminal:
```bash
firebase login:ci
```

This will generate a token. Keep it safe!

## Step 4: Configure Codemagic Environment Variables

1. Go to Codemagic Dashboard → Your App → Settings → Environment variables
2. Add the following variables:

| Variable Name | Value | Group | Secure |
|--------------|-------|-------|--------|
| `FIREBASE_TOKEN` | (token from Step 3) | firebase | ✓ |
| `FIREBASE_PROJECT_ID` | your-firebase-project-id | firebase | - |
| `YOUR_ANDROID_APP_ID` | Get from Firebase Console | firebase | - |
| `YOUR_IOS_APP_ID` | Get from Firebase Console | firebase | - |

### How to get App IDs:
1. Go to Firebase Console → Project Settings
2. Scroll to **Your apps** section
3. Copy the **App ID** for each platform (format: `1:123456789:android:abc123def456`)

## Step 5: Update codemagic.yaml

Replace the following placeholders in `codemagic.yaml`:

```yaml
# In both workflows, update:
vars:
  FIREBASE_PROJECT_ID: "your-actual-firebase-project-id"  # From Firebase Console
  FIREBASE_TOKEN: $FIREBASE_TOKEN  # This references the env variable

# In publishing section:
firebase:
  firebase_token: $FIREBASE_TOKEN
  android:
    app_id: 1:123456789:android:abc123def456  # Your actual Android App ID
    groups:
      - testers  # Or your custom group name
  ios:
    app_id: 1:123456789:ios:abc123def456  # Your actual iOS App ID
    groups:
      - testers

# Update email:
email:
  recipients:
    - your-email@example.com  # Your actual email
```

## Step 6: Android Signing Configuration

For production builds, you need to add Android signing:

1. Generate keystore (if you don't have one):
```bash
keytool -genkey -v -keystore yourturn-release.keystore -alias yourturn -keyalg RSA -keysize 2048 -validity 10000
```

2. In Codemagic:
   - Go to **Code signing identities**
   - Upload your keystore file
   - Add keystore password, key alias, and key password
   - Get the keystore reference name

3. Update codemagic.yaml:
```yaml
environment:
  android_signing:
    - yourturn_keystore  # Your keystore reference name
```

## Step 7: iOS Signing Configuration (Optional)

For signed iOS builds:

1. In Codemagic, go to **Code signing identities**
2. Add your Apple Developer account
3. Upload provisioning profiles and certificates
4. Update codemagic.yaml:
```yaml
environment:
  ios_signing:
    distribution_type: ad_hoc  # or app_store
    bundle_identifier: com.tendimensions.yourturn
```

5. Update ExportOptions.plist with your Team ID:
   - Find Team ID in Apple Developer Portal
   - Replace `YOUR_TEAM_ID` in `ios/ExportOptions.plist`

## Step 8: Test Your Configuration

1. Commit and push your changes to the `main` branch
2. Codemagic will automatically trigger `flutter-workflow`
3. Check build logs for any errors
4. Once successful, check Firebase App Distribution for the uploaded APK/IPA
5. Testers will receive an email notification

## Manual Dev Builds

To trigger a manual dev build:
1. Go to Codemagic Dashboard
2. Select your app
3. Click **Start new build**
4. Select `flutter-dev-workflow`
5. Click **Start build**

## Troubleshooting

### Common Issues:

1. **"Firebase token invalid"**
   - Re-run `firebase login:ci` and update the token in Codemagic

2. **"App ID not found"**
   - Verify the App ID format in Firebase Console
   - Ensure it matches exactly (including the `1:` prefix)

3. **"No signing identity"**
   - For Android: Add keystore configuration
   - For iOS: Add provisioning profiles

4. **"CocoaPods failed"**
   - Check ios/Podfile for errors
   - Ensure all dependencies are compatible

5. **"Tests failed"**
   - Add actual tests or the build will continue anyway (we set `ignore_failure: true`)

## Next Steps

After successful setup:
- [ ] Add proper unit tests
- [ ] Configure release signing
- [ ] Set up staged rollouts
- [ ] Add release notes automation
- [ ] Configure Slack/Discord notifications

## Useful Links

- [Firebase Console](https://console.firebase.google.com)
- [Codemagic Docs](https://docs.codemagic.io)
- [Firebase App Distribution Docs](https://firebase.google.com/docs/app-distribution)
