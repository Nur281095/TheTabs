import 'package:firebase_auth/firebase_auth.dart';
import '../utils/firestore_service.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Phone Authentication

  /// Validate Firebase configuration for phone auth
  Future<bool> validateFirebaseConfig() async {
    try {
      print('Validating Firebase configuration...');
      print('Firebase App: ${_auth.app.name}');
      print('Firebase Project ID: ${_auth.app.options.projectId}');
      print('Auth instance: ${_auth.toString()}');
      return true;
    } catch (e) {
      print('Firebase configuration error: $e');
      return false;
    }
  }

  /// Send OTP to phone number
  /// [phoneNumber] - Phone number with country code (+1234567890)
  /// [verificationCompleted] - Callback for automatic verification
  /// [verificationFailed] - Callback for verification failure
  /// [codeSent] - Callback when OTP is sent
  /// [codeAutoRetrievalTimeout] - Callback for timeout
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    try {
      // Validate Firebase configuration first
      await validateFirebaseConfig();
      
      // Validate phone number format
      if (!phoneNumber.startsWith('+')) {
        throw FirebaseAuthException(
          code: 'invalid-phone-number',
          message: 'Phone number must start with country code (+)',
        );
      }

      print('Attempting to verify phone number: $phoneNumber');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print('Error sending OTP: $e');
      rethrow;
    }
  }

  /// Verify OTP and sign in
  /// [verificationId] - Verification ID from codeSent callback
  /// [otp] - OTP code entered by user
  Future<UserCredential?> verifyOTPAndSignIn({
    required String verificationId,
    required String otp,
  }) async {
    try {
      print('Creating phone credential for verification...');
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      print('Signing in with credential...');
      final userCredential = await _auth.signInWithCredential(credential);
      
      print('Sign in successful. User ID: ${userCredential.user?.uid}');
      print('Is new user: ${userCredential.additionalUserInfo?.isNewUser}');
      
      // Always create/update user profile for phone auth users
      // Phone auth users may not be detected as "new" correctly
      if (userCredential.user != null) {
        print('Creating/updating user profile...');
        await _createOrUpdateUserProfile(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      print('Error verifying OTP: $e');
      return null;
    }
  }

  /// Create user profile in Firestore
  /// [user] - Firebase User object
  Future<void> _createUserProfile(User user) async {
    try {
      print('Creating user profile for UID: ${user.uid}');
      print('Phone number: ${user.phoneNumber}');
      
      final userModel = UserModel(
        uid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        displayName: user.displayName ?? 'User',
        profilePhotoUrl: user.photoURL,
        about: null,
        onlineStatus: 'online',
        lastSeen: DateTime.now(),
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('User model created: ${userModel.toMap()}');
      
      final success = await _firestoreService.createUserProfile(
        userId: user.uid,
        userData: userModel.toMap(),
      );
      
      if (success) {
        print('User profile created successfully in Firestore');
      } else {
        print('Failed to create user profile in Firestore');
      }
    } catch (e) {
      print('Error creating user profile: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Create or update user profile in Firestore
  /// [user] - Firebase User object
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      print('Creating/updating user profile for UID: ${user.uid}');
      print('Phone number: ${user.phoneNumber}');
      
      // Check if user profile already exists
      final existingProfile = await _firestoreService.getUserProfile(userId: user.uid);
      
      if (existingProfile != null) {
        print('User profile already exists, updating last seen and online status');
        await _firestoreService.updateUserProfile(
          userId: user.uid,
          userData: {
            'onlineStatus': 'online',
            'lastSeen': DateTime.now(),
            'updatedAt': DateTime.now(),
          },
        );
        return;
      }
      
      // Create new profile
      final userModel = UserModel(
        uid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        displayName: user.displayName ?? 'User',
        profilePhotoUrl: user.photoURL,
        about: null,
        onlineStatus: 'online',
        lastSeen: DateTime.now(),
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Creating new user model: ${userModel.toMap()}');
      
      final success = await _firestoreService.createUserProfile(
        userId: user.uid,
        userData: userModel.toMap(),
      );
      
      if (success) {
        print('User profile created successfully in Firestore');
      } else {
        print('Failed to create user profile in Firestore');
        throw Exception('Failed to create user profile');
      }
    } catch (e) {
      print('Error creating/updating user profile: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Get user profile as UserModel
  /// [userId] - User ID (optional, uses current user if not provided)
  Future<UserModel?> getUserProfileModel({String? userId}) async {
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return null;
    
    try {
      final userData = await _firestoreService.getUserProfile(userId: targetUserId);
      if (userData != null) {
        return UserModel.fromMap(userData);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile
  /// [userData] - Updated user data
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    if (currentUserId == null) return false;
    
    try {
      return await _firestoreService.updateUserProfile(
        userId: currentUserId!,
        userData: userData,
      );
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  /// Get user profile
  /// [userId] - User ID (optional, uses current user if not provided)
  Future<Map<String, dynamic>?> getUserProfile({String? userId}) async {
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return null;
    
    try {
      return await _firestoreService.getUserProfile(userId: targetUserId);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user online status
  /// [isOnline] - Online status
  Future<void> updateOnlineStatus({required bool isOnline}) async {
    if (currentUserId == null) return;
    
    try {
      final updateData = {
        'onlineStatus': isOnline ? 'online' : 'offline',
        'lastSeen': DateTime.now(),
      };
      
      await _firestoreService.updateUserProfile(
        userId: currentUserId!,
        userData: updateData,
      );
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    print('Starting sign out process...');
    
    try {
      final userId = currentUserId;
      
      // Try to update offline status but don't let it block sign out
      if (userId != null) {
        try {
          await _firestoreService.updateUserProfile(
            userId: userId,
            userData: {
              'onlineStatus': 'offline',
              'lastSeen': DateTime.now(),
            },
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('Timeout updating user status, continuing with sign out');
              return false;
            },
          );
          print('User status updated to offline');
        } catch (e) {
          print('Error updating online status before signout: $e');
          // Continue with sign out even if status update fails
        }
      }
      
      // Always attempt Firebase sign out with timeout
      try {
        await _auth.signOut().timeout(
          const Duration(seconds: 5),
          onTimeout: () async {
            print('Firebase sign out timeout, forcing local sign out');
            // Force local sign out even if Firebase is unresponsive
            return;
          },
        );
        print('Firebase sign out completed');
      } catch (e) {
        print('Firebase sign out error: $e, continuing anyway');
        // Even if Firebase sign out fails, we proceed
      }
      
      print('User signed out successfully');
    } catch (e) {
      print('Error during sign out process: $e');
      // Don't rethrow - we want to complete the sign out process
      print('Forcing sign out completion despite errors');
    }
  }

  /// Delete user account
  Future<bool> deleteAccount() async {
    if (currentUser == null) return false;
    
    try {
      final userId = currentUserId!;
      
      // Delete user data from Firestore
      // You might want to delete related data like conversations, messages, etc.
      await _firestoreService.deleteDocument(
        collection: 'users',
        documentId: userId,
      );
      
      // Delete Firebase Auth account
      await currentUser!.delete();
      
      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // Utility Methods

  /// Re-authenticate user with phone credential
  /// [verificationId] - Verification ID
  /// [otp] - OTP code
  Future<bool> reauthenticateWithPhone({
    required String verificationId,
    required String otp,
  }) async {
    if (currentUser == null) return false;
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      await currentUser!.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Error re-authenticating: $e');
      return false;
    }
  }

  /// Update phone number
  /// [verificationId] - Verification ID for new phone number
  /// [otp] - OTP code for new phone number
  Future<bool> updatePhoneNumber({
    required String verificationId,
    required String otp,
  }) async {
    if (currentUser == null) return false;
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      await currentUser!.updatePhoneNumber(credential);
      
      // Update phone number in Firestore
      await updateUserProfile({
        'phoneNumber': currentUser!.phoneNumber ?? '',
      });
      
      return true;
    } catch (e) {
      print('Error updating phone number: $e');
      return false;
    }
  }

  /// Check if phone number is already registered
  /// [phoneNumber] - Phone number to check
  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    try {
      // This is a workaround since Firebase doesn't provide direct method
      // You can implement your own logic here
      final methods = await _auth.fetchSignInMethodsForEmail('$phoneNumber@temp.com');
      return methods.isNotEmpty;
    } catch (e) {
      // If error occurs, assume phone number is not registered
      return false;
    }
  }

  /// Get error message from exception
  /// [exception] - Firebase Auth exception
  String getErrorMessage(FirebaseAuthException exception) {
    // Add detailed logging for debugging
    print('Firebase Auth Error Details:');
    print('Code: ${exception.code}');
    print('Message: ${exception.message}');
    print('Stack Trace: ${exception.stackTrace}');
    
    switch (exception.code) {
      case 'internal-error':
        return 'Internal error occurred. Please check your Firebase configuration and ensure SHA fingerprints are added to your Firebase project.';
      case 'invalid-phone-number':
        return 'The phone number format is invalid. Please include the country code.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please enable it in Firebase Console.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'invalid-verification-code':
        return 'The verification code is invalid. Please try again.';
      case 'invalid-verification-id':
        return 'The verification ID is invalid. Please request a new code.';
      case 'session-expired':
        return 'The verification session has expired. Please request a new code.';
      default:
        return exception.message ?? 'An unknown authentication error occurred.';
    }
  }
}
