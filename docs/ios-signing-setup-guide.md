# iOS Signing Setup for YourTurn in Codemagic

This guide explains how to set up the `ios_signing` environment variable group in Codemagic for the YourTurn app.

## Overview

You need three environment variables in the `ios_signing` group:

1. `CM_CERTIFICATE` - Your iOS distribution certificate (base64)
2. `CM_CERTIFICATE_PASSWORD` - Password for the certificate
3. `CM_PROVISIONING_PROFILE` - YourTurn's provisioning profile (base64)

**Important**: Variables #1 and #2 can be reused from TagTakeover (same certificate works for all your apps). Variable #3 must be specific to YourTurn's bundle ID: `com.tendimensions.yourturn`

---

## Step 1: Get CM_CERTIFICATE (from Apple Developer Portal)

### If you already have the certificate file (.p12)

1. Open PowerShell
2. Navigate to where your certificate file is located
3. Run this command (replace the path with your actual file path):

```powershell
$certPath = "C:\path\to\your\certificate.p12"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($certPath)) | Set-Clipboard
```

1. The base64 string is now in your clipboard
2. In Codemagic → YourTurn → Environment variables → Click "Add"
   - Variable name: `CM_CERTIFICATE`
   - Value: Paste from clipboard
   - Group: `ios_signing`
   - Check "Secret": ✓ Yes
3. Click Save

### If you need to download/create the certificate

1. Go to <https://developer.apple.com/account/resources/certificates>
2. Sign in with your Apple ID
3. Click the **+** button to create a new certificate (or download existing)
4. Choose **iOS Distribution** certificate type
5. Follow the prompts to create a Certificate Signing Request (CSR):
   - Open **Keychain Access** on Mac (or use OpenSSL on Windows)
   - Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
   - Enter your email, name, select "Saved to disk"
   - Upload the CSR file to Apple Developer Portal
6. Download the certificate (.cer file)
7. Double-click to install it in Keychain Access (Mac only)
8. Export as .p12:
   - Right-click the certificate → Export
   - Save as .p12 format
   - Set a password (this becomes your CM_CERTIFICATE_PASSWORD)
9. Convert to base64 using the PowerShell command above

---

## Step 2: Get CM_CERTIFICATE_PASSWORD

This is the password you set when you exported the certificate as a .p12 file.

1. In Codemagic → YourTurn → Environment variables → Click "Add"
   - Variable name: `CM_CERTIFICATE_PASSWORD`
   - Value: Your certificate password
   - Group: `ios_signing`
   - Check "Secret": ✓ Yes
2. Click Save

**Note**: If you're reusing the certificate from TagTakeover, this is the same password.

---

## Step 3: Get CM_PROVISIONING_PROFILE (specific to YourTurn)

### Download the Provisioning Profile

1. Go to <https://developer.apple.com/account/resources/profiles>
2. Sign in with your Apple ID
3. Look for a provisioning profile for **com.tendimensions.yourturn**
   - If it exists, download it
   - If it doesn't exist, create a new one:

#### To create a new provisioning profile

1. Click the **+** button
2. Select **Ad Hoc** (for Firebase App Distribution testing)
3. Click Continue
4. Select your App ID: **com.tendimensions.yourturn**
   - If the App ID doesn't exist, you need to create it first:
     - Go to Identifiers → Click +
     - Select App IDs → Continue
     - Description: YourTurn
     - Bundle ID: `com.tendimensions.yourturn`
     - Save
5. Select your distribution certificate (the one you used in Step 1)
6. Select the devices you want to test on (for Ad Hoc distribution)
7. Give it a name: "YourTurn AdHoc Profile"
8. Click Generate
9. Download the .mobileprovision file

### Convert to Base64

1. Open PowerShell
2. Navigate to where you downloaded the .mobileprovision file
3. Run this command (replace the path):

```powershell
$profilePath = "C:\path\to\YourTurn_AdHoc_Profile.mobileprovision"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($profilePath)) | Set-Clipboard
```

1. The base64 string is now in your clipboard
2. In Codemagic → YourTurn → Environment variables → Click "Add"
   - Variable name: `CM_PROVISIONING_PROFILE`
   - Value: Paste from clipboard
   - Group: `ios_signing`
   - Check "Secret": ✓ Yes
3. Click Save

---

## Step 4: Verify Your Setup

After adding all three variables, verify:

1. Go to Codemagic → YourTurn → Environment variables
2. You should see a group called `ios_signing` with 3 variables:
   - CM_CERTIFICATE (marked as secret)
   - CM_CERTIFICATE_PASSWORD (marked as secret)
   - CM_PROVISIONING_PROFILE (marked as secret)
3. All three should show dots (•••••••) indicating they're encrypted

---

## Step 5: Trigger a Build

1. Commit and push any pending changes to your repository
2. In Codemagic, go to YourTurn → Start new build
3. The iOS build should now succeed and create an IPA file
4. The IPA will be uploaded to Firebase App Distribution

---

## Troubleshooting

### "No identity found" error

- Verify CM_CERTIFICATE is the complete base64 string (no truncation)
- Verify CM_CERTIFICATE_PASSWORD is correct

### "No matching provisioning profile found"

- Verify the provisioning profile's bundle ID matches: `com.tendimensions.yourturn`
- Verify the provisioning profile includes your distribution certificate
- Verify CM_PROVISIONING_PROFILE is the complete base64 string

### "Certificate has expired"

- Check certificate expiration in Apple Developer Portal
- Generate a new certificate if expired
- Update CM_CERTIFICATE with new certificate

### Build succeeds but no IPA file

- Check the build logs for signing errors
- Verify the provisioning profile includes test devices (for Ad Hoc)
- Check that the profile hasn't expired

---

## Quick Reference: PowerShell Commands

### Convert Certificate to Base64

```powershell
$certPath = "C:\path\to\certificate.p12"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($certPath)) | Set-Clipboard
```

### Convert Provisioning Profile to Base64

```powershell
$profilePath = "C:\path\to\profile.mobileprovision"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($profilePath)) | Set-Clipboard
```

---

## Important URLs

- Apple Developer Account: <https://developer.apple.com/account>
- Certificates: <https://developer.apple.com/account/resources/certificates>
- Provisioning Profiles: <https://developer.apple.com/account/resources/profiles>
- Identifiers (App IDs): <https://developer.apple.com/account/resources/identifiers>
- Codemagic Dashboard: <https://codemagic.io/apps>

---

## Summary Checklist

- [ ] Downloaded/have iOS Distribution certificate (.p12)
- [ ] Know the certificate password
- [ ] Created App ID: com.tendimensions.yourturn (if needed)
- [ ] Created Ad Hoc provisioning profile for YourTurn
- [ ] Downloaded provisioning profile (.mobileprovision)
- [ ] Converted certificate to base64
- [ ] Converted provisioning profile to base64
- [ ] Added CM_CERTIFICATE to Codemagic
- [ ] Added CM_CERTIFICATE_PASSWORD to Codemagic
- [ ] Added CM_PROVISIONING_PROFILE to Codemagic
- [ ] All three variables are in `ios_signing` group
- [ ] All three variables are marked as Secret
- [ ] Triggered a test build
- [ ] Build succeeded and created IPA

---

**Last Updated**: February 1, 2026
