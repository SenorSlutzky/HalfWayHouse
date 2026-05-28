# Half Way House - Setup Guide

## Prerequisites

1. **Mac with Xcode 15+** installed (download from Mac App Store)
2. **Apple Developer Account** ($99/year) — required for App Store & Apple Sign-In
3. **Google/Firebase Account** — free at [console.firebase.google.com](https://console.firebase.google.com)
4. **Node.js 18+** — for Firebase Cloud Functions

---

## Step 1: Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project" → Name it "HalfWayHouse"
3. Enable Google Analytics (optional but recommended)
4. Once created, click the iOS icon to add an iOS app:
   - Bundle ID: `com.senorslutzky.HalfWayHouse`
   - Download `GoogleService-Info.plist`
   - Place it in `HalfWayHouse/Resources/`

### Enable Services:
- **Authentication** → Sign-in method → Enable "Apple"
- **Realtime Database** → Create database → Start in test mode (we'll add rules later)
- **Storage** → Get started → Start in test mode
- **Cloud Messaging** → Enabled by default

### Deploy Security Rules:
```bash
cd Firebase
firebase login
firebase init  # Select Realtime Database
firebase deploy --only database
```

### Deploy Cloud Functions:
```bash
cd Firebase/functions
npm install
cd ..
firebase deploy --only functions
```

---

## Step 2: Xcode Project Setup

1. Open Xcode → Create new project → iOS App
2. Product Name: `HalfWayHouse`
3. Bundle Identifier: `com.senorslutzky.HalfWayHouse`
4. Interface: SwiftUI
5. Language: Swift

### Add Firebase SDK:
- File → Add Package Dependencies
- URL: `https://github.com/firebase/firebase-ios-sdk.git`
- Select: FirebaseAuth, FirebaseDatabase, FirebaseStorage, FirebaseMessaging, FirebaseAnalytics

### Add Capabilities:
- Signing & Capabilities → + Capability:
  - **Sign in with Apple**
  - **Push Notifications**
  - **Background Modes** → Remote notifications

### Add GoogleService-Info.plist:
- Drag `GoogleService-Info.plist` into the project navigator
- Ensure "Copy items if needed" is checked
- Add to target: HalfWayHouse

---

## Step 3: Copy Source Files

Copy all `.swift` files from this repo into your Xcode project:
- `HalfWayHouse/App/` → App entry point
- `HalfWayHouse/Models/` → Data models
- `HalfWayHouse/ViewModels/` → Business logic
- `HalfWayHouse/Services/` → Firebase service layer
- `HalfWayHouse/Views/` → All UI screens

---

## Step 4: Apple Sign-In Configuration

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Certificates, Identifiers & Profiles → Identifiers
3. Select your app ID → Enable "Sign In with Apple"
4. In Firebase Console → Authentication → Apple:
   - Add Services ID
   - Configure redirect URL from Firebase

---

## Step 5: Push Notifications Setup

1. Apple Developer Portal → Keys → Create new key
2. Enable "Apple Push Notifications service (APNs)"
3. Download the `.p8` file
4. In Firebase Console → Project Settings → Cloud Messaging:
   - Upload the APNs key
   - Enter Key ID and Team ID

---

## Step 6: Seed Course Data

Run the seed script to populate your database with initial course data:

```bash
cd Firebase
node seed-courses.js
```

Or manually add courses in Firebase Console → Realtime Database.

---

## Step 7: Test

1. Run on physical device (push notifications don't work on simulator)
2. Sign in with Apple
3. Generate invite code → Share with a friend
4. Start a round → Enter scores → Verify real-time sync

---

## Step 8: TestFlight & App Store

1. In Xcode: Product → Archive
2. Distribute App → App Store Connect
3. In App Store Connect:
   - Add screenshots
   - Write description
   - Set privacy policy URL
   - Submit for review

---

## Environment Variables

Create a `.env` file for local development (DO NOT commit):

```
FIREBASE_PROJECT_ID=halfwayhouse-xxxxx
FIREBASE_API_KEY=your-api-key
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No matching provisioning profile" | Xcode → Signing → Enable Automatic |
| Apple Sign-In fails | Check Services ID matches Firebase config |
| Push notifications not received | Use physical device, check APNs key |
| Real-time updates not working | Check database rules allow read access |
| Cloud Functions not triggering | Check `firebase deploy --only functions` succeeded |

---

## Architecture Notes

- **Firebase Realtime Database** chosen over Firestore for lowest-latency live scoring
- **Cloud Functions** handle leaderboard calculation server-side to prevent cheating
- **Invite codes** expire after 7 days for security
- **Database rules** ensure players can only read/write their own data and shared rounds
