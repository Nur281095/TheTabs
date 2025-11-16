# Firebase Setup Guide for TABS Chat App

## Overview
This guide explains how to set up Firebase for the TABS chat application with phone authentication and Firestore database.

## 🔥 Firebase Services Used
- **Firebase Authentication** - Phone number authentication with OTP
- **Cloud Firestore** - NoSQL database for storing user data, conversations, and messages
- **Firebase Storage** - For storing user profile images and media files

## 📋 Prerequisites
1. A Google account
2. A Flutter project (already created)
3. Firebase CLI installed (optional but recommended)

## 🚀 Setup Steps

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `tabs-chat-app` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

### 2. Add Firebase to Your Flutter App

#### For Android:
1. In Firebase Console, click "Add app" → Android
2. Enter Android package name: `com.example.tabs`
3. Download `google-services.json`
4. Place it in `android/app/` directory
5. Add to `android/build.gradle`:
   ```gradle
   buildscript {
     dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
     }
   }
   ```
6. Add to `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

#### For iOS:
1. In Firebase Console, click "Add app" → iOS
2. Enter iOS bundle ID: `com.example.tabs`
3. Download `GoogleService-Info.plist`
4. Add it to `ios/Runner/` in Xcode
5. Update `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLName</key>
       <string>REVERSED_CLIENT_ID</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

### 3. Enable Authentication
1. In Firebase Console → Authentication → Sign-in method
2. Enable "Phone" provider
3. Add your phone numbers to test phone numbers (for development)

### 4. Set up Firestore Database
1. In Firebase Console → Firestore Database
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select location closest to your users

### 5. Configure Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Conversations - users can read/write if they're participants
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      
      // Messages within conversations
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }
    
    // Public read access for user discovery (optional)
    match /users/{userId} {
      allow read: if request.auth != null;
    }
  }
}
```

## 📱 Using the FirestoreService Utility

### Basic CRUD Operations

#### Create Document
```dart
final firestoreService = FirestoreService();

// Create a user profile
await firestoreService.createDocument(
  collection: 'users',
  documentId: 'user123',
  data: {
    'name': 'John Doe',
    'email': 'john@example.com',
    'phoneNumber': '+1234567890',
  },
);
```

#### Read Documents
```dart
// Get single document
final userData = await firestoreService.getDocument(
  collection: 'users',
  documentId: 'user123',
);

// Get multiple documents with filtering
final conversations = await firestoreService.getDocuments(
  collection: 'conversations',
  orderBy: 'lastMessageTime',
  descending: true,
  limit: 20,
  where: [['participants', 'array-contains', 'user123']],
);
```

#### Update Document
```dart
await firestoreService.updateDocument(
  collection: 'users',
  documentId: 'user123',
  data: {
    'name': 'John Smith',
    'lastSeen': DateTime.now().toIso8601String(),
  },
);
```

#### Delete Document
```dart
await firestoreService.deleteDocument(
  collection: 'users',
  documentId: 'user123',
);
```

### Real-time Updates
```dart
// Listen to document changes
Stream<Map<String, dynamic>?> userStream = firestoreService.getDocumentStream(
  collection: 'users',
  documentId: 'user123',
);

// Listen to collection changes
Stream<List<Map<String, dynamic>>> conversationsStream = 
  firestoreService.getDocumentsStream(
    collection: 'conversations',
    orderBy: 'lastMessageTime',
    descending: true,
  );
```

### Chat-specific Operations
```dart
// Create conversation
final conversationId = await firestoreService.createConversation(
  participants: ['user1', 'user2'],
  conversationData: {
    'title': 'Project Discussion',
    'type': 'private',
  },
);

// Send message
await firestoreService.sendMessage(
  conversationId: conversationId!,
  messageData: {
    'senderId': 'user1',
    'content': 'Hello there!',
    'type': 'text',
    'timestamp': DateTime.now().toIso8601String(),
  },
);

// Get messages
final messages = await firestoreService.getMessages(
  conversationId: conversationId,
  limit: 50,
);
```

## 🔐 Using the AuthService

### Phone Authentication
```dart
final authService = AuthService();

// Send OTP
await authService.sendOTP(
  phoneNumber: '+1234567890',
  verificationCompleted: (credential) {
    // Auto-verification completed
  },
  verificationFailed: (exception) {
    // Handle error
    print('Verification failed: ${authService.getErrorMessage(exception)}');
  },
  codeSent: (verificationId, resendToken) {
    // Navigate to OTP screen
  },
  codeAutoRetrievalTimeout: (verificationId) {
    // Handle timeout
  },
);

// Verify OTP
final userCredential = await authService.verifyOTPAndSignIn(
  verificationId: verificationId,
  otp: '123456',
);
```

### User Management
```dart
// Get current user profile
final userProfile = await authService.getUserProfile();

// Update user profile
await authService.updateUserProfile({
  'displayName': 'John Doe',
  'status': 'Available for chat',
});

// Update online status
await authService.updateOnlineStatus(isOnline: true);

// Sign out
await authService.signOut();
```

## 📊 Database Structure

### Users Collection
```
users/{userId}
├── uid: string
├── phoneNumber: string
├── displayName: string
├── email: string
├── photoURL: string
├── status: string
├── isActive: boolean
├── lastSeen: string (ISO date)
├── joinedAt: string (ISO date)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Conversations Collection
```
conversations/{conversationId}
├── participants: array[string]
├── lastMessage: string
├── lastMessageTime: timestamp
├── isActive: boolean
├── createdAt: timestamp
├── updatedAt: timestamp
└── messages/{messageId}
    ├── senderId: string
    ├── content: string
    ├── type: string (text, image, video, audio)
    ├── timestamp: string
    ├── mediaUrl: string (optional)
    ├── thumbnailUrl: string (optional)
    ├── createdAt: timestamp
    └── updatedAt: timestamp
```

## 🔧 Error Handling

### Common Firebase Auth Errors
- `invalid-phone-number`: Invalid phone format
- `too-many-requests`: Rate limit exceeded
- `invalid-verification-code`: Wrong OTP
- `quota-exceeded`: SMS quota exceeded

### Error Handling Example
```dart
try {
  await authService.sendOTP(/* parameters */);
} on FirebaseAuthException catch (e) {
  final errorMessage = authService.getErrorMessage(e);
  _showSnackBar(errorMessage);
} catch (e) {
  _showSnackBar('An unexpected error occurred');
}
```

## 🧪 Testing

### Test Phone Numbers (for development)
Add these in Firebase Console → Authentication → Sign-in method → Phone:
- `+1 650-555-3434` → OTP: `654321`
- `+1 408-555-5555` → OTP: `123456`

### Local Testing
1. Use Android/iOS emulator
2. Test with real device for production
3. Ensure internet connectivity
4. Check Firebase Console for logs

## 🚀 Deployment Checklist

### Before Production:
1. ✅ Update Firestore security rules
2. ✅ Configure proper authentication settings
3. ✅ Set up Firebase hosting (optional)
4. ✅ Configure proper error handling
5. ✅ Test on real devices
6. ✅ Set up monitoring and analytics
7. ✅ Configure backup strategies

## 📞 Support

If you encounter issues:
1. Check Firebase Console logs
2. Verify configuration files
3. Ensure internet connectivity
4. Check Firebase service status
5. Review security rules

## 📚 Additional Resources
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
