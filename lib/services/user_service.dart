import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_service.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  /// Search users by multiple criteria
  /// Supports phone number (exact match) and display name (partial match)
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null || query.trim().isEmpty) return [];

      final searchQuery = query.trim().toLowerCase();
      List<UserModel> results = [];

      // Search by phone number (exact match)
      if (_isPhoneNumber(searchQuery)) {
        final phoneResults = await _searchByPhoneNumber(searchQuery, currentUserId);
        results.addAll(phoneResults);
      }

      // Search by display name (partial match)
      final nameResults = await _searchByDisplayName(searchQuery, currentUserId);
      results.addAll(nameResults);

      // Remove duplicates based on user ID
      final uniqueResults = <String, UserModel>{};
      for (final user in results) {
        uniqueResults[user.uid] = user;
      }

      // Sort by relevance: exact matches first, then partial matches
      final sortedResults = uniqueResults.values.toList();
      sortedResults.sort((a, b) {
        // Prioritize exact name matches
        final aExactMatch = a.displayName?.toLowerCase() == searchQuery;
        final bExactMatch = b.displayName?.toLowerCase() == searchQuery;
        
        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;
        
        // Then sort by online status (online users first)
        if (a.onlineStatus == 'online' && b.onlineStatus != 'online') return -1;
        if (a.onlineStatus != 'online' && b.onlineStatus == 'online') return 1;
        
        // Finally sort alphabetically by display name
        return (a.displayName ?? '').compareTo(b.displayName ?? '');
      });

      return sortedResults;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Search users by phone number (exact match)
  Future<List<UserModel>> _searchByPhoneNumber(String phoneNumber, String currentUserId) async {
    try {
      // Try different phone number formats
      final phoneFormats = _generatePhoneFormats(phoneNumber);
      final Set<UserModel> users = {};

      for (final format in phoneFormats) {
        final docs = await _firestoreService.getDocuments(
          collection: 'users',
          where: [['phoneNumber', '==', format]],
          limit: 5,
        );

        for (final doc in docs) {
          final user = UserModel.fromMap(doc);
          if (user.uid != currentUserId) {
            users.add(user);
          }
        }
      }

      return users.toList();
    } catch (e) {
      print('Error searching by phone number: $e');
      return [];
    }
  }

  /// Search users by display name (partial match)
  Future<List<UserModel>> _searchByDisplayName(String searchQuery, String currentUserId) async {
    try {
      // Firestore doesn't support full-text search, so we'll use range queries
      // This is a basic implementation - for production, consider using Algolia or ElasticSearch
      
      final searchLower = searchQuery.toLowerCase();
      final searchUpper = searchQuery.toLowerCase() + '\uf8ff';

      final docs = await _firestoreService.getDocuments(
        collection: 'users',
        orderBy: 'displayName',
        limit: 20,
      );

      final List<UserModel> matchingUsers = [];

      for (final doc in docs) {
        final user = UserModel.fromMap(doc);
        
        // Skip current user
        if (user.uid == currentUserId) continue;

        // Check if display name contains the search query
        final displayName = user.displayName?.toLowerCase() ?? '';
        if (displayName.contains(searchLower)) {
          matchingUsers.add(user);
        }
      }

      return matchingUsers;
    } catch (e) {
      print('Error searching by display name: $e');
      return [];
    }
  }

  /// Get all users with pagination and filtering
  Future<List<UserModel>> getAllUsers({
    int limit = 50,
    String? lastUserId,
    bool onlineOnly = false,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      List<List<dynamic>> whereConditions = [];
      
      if (onlineOnly) {
        whereConditions.add(['onlineStatus', '==', 'online']);
      }

      final docs = await _firestoreService.getDocuments(
        collection: 'users',
        where: whereConditions.isEmpty ? null : whereConditions,
        orderBy: 'displayName',
        limit: limit,
      );

      return docs
          .where((doc) => doc['uid'] != currentUserId)
          .map((data) => UserModel.fromMap(data))
          .toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  /// Get users by their online status
  Future<List<UserModel>> getUsersByStatus(String status) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      final docs = await _firestoreService.getDocuments(
        collection: 'users',
        where: [['onlineStatus', '==', status]],
        orderBy: 'lastSeen',
        descending: true,
        limit: 50,
      );

      return docs
          .where((doc) => doc['uid'] != currentUserId)
          .map((data) => UserModel.fromMap(data))
          .toList();
    } catch (e) {
      print('Error getting users by status: $e');
      return [];
    }
  }

  /// Get recently active users
  Future<List<UserModel>> getRecentlyActiveUsers() async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      // Get users active in the last 24 hours
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final docs = await _firestoreService.getDocuments(
        collection: 'users',
        orderBy: 'lastSeen',
        descending: true,
        limit: 30,
      );

      return docs
          .where((doc) {
            final user = UserModel.fromMap(doc);
            return user.uid != currentUserId && 
                   user.lastSeen != null && 
                   user.lastSeen!.isAfter(yesterday);
          })
          .map((data) => UserModel.fromMap(data))
          .toList();
    } catch (e) {
      print('Error getting recently active users: $e');
      return [];
    }
  }

  /// Search users by multiple fields with advanced filtering
  Future<List<UserModel>> advancedUserSearch({
    String? nameQuery,
    String? phoneQuery,
    List<String>? statusFilter, // ['online', 'away']
    bool? isAvailable,
    int limit = 20,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      // Get all users first (since Firestore has limited query capabilities)
      final docs = await _firestoreService.getDocuments(
        collection: 'users',
        orderBy: 'displayName',
        limit: 100, // Get more to filter client-side
      );

      List<UserModel> filteredUsers = [];

      for (final doc in docs) {
        final user = UserModel.fromMap(doc);
        
        // Skip current user
        if (user.uid == currentUserId) continue;

        bool matches = true;

        // Filter by name
        if (nameQuery != null && nameQuery.isNotEmpty) {
          final displayName = user.displayName?.toLowerCase() ?? '';
          if (!displayName.contains(nameQuery.toLowerCase())) {
            matches = false;
          }
        }

        // Filter by phone
        if (phoneQuery != null && phoneQuery.isNotEmpty) {
          if (!user.phoneNumber.contains(phoneQuery)) {
            matches = false;
          }
        }

        // Filter by status
        if (statusFilter != null && statusFilter.isNotEmpty) {
          if (!statusFilter.contains(user.onlineStatus)) {
            matches = false;
          }
        }

        // Filter by availability
        if (isAvailable != null) {
          if (user.isAvailable != isAvailable) {
            matches = false;
          }
        }

        if (matches) {
          filteredUsers.add(user);
        }

        // Respect limit
        if (filteredUsers.length >= limit) break;
      }

      return filteredUsers;
    } catch (e) {
      print('Error in advanced user search: $e');
      return [];
    }
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final userData = await _firestoreService.getUserProfile(userId: userId);
      if (userData != null) {
        return UserModel.fromMap(userData);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  /// Get multiple users by their IDs
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];

      final List<UserModel> users = [];
      
      // Firestore 'in' queries are limited to 10 items, so batch the requests
      const batchSize = 10;
      
      for (int i = 0; i < userIds.length; i += batchSize) {
        final batch = userIds.skip(i).take(batchSize).toList();
        
        final docs = await _firestoreService.getDocuments(
          collection: 'users',
          where: [['uid', 'in', batch]],
        );

        users.addAll(docs.map((data) => UserModel.fromMap(data)));
      }

      return users;
    } catch (e) {
      print('Error getting users by IDs: $e');
      return [];
    }
  }

  /// Utility method to check if a string looks like a phone number
  bool _isPhoneNumber(String input) {
    // Basic phone number pattern - adjust based on your requirements
    final phoneRegex = RegExp(r'^[\+]?[0-9\-\(\)\s]{7,}$');
    return phoneRegex.hasMatch(input);
  }

  /// Generate different phone number formats for search
  List<String> _generatePhoneFormats(String phoneNumber) {
    final formats = <String>{};
    
    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add original format
    formats.add(phoneNumber);
    
    // Add digits only
    formats.add(digitsOnly);
    
    // Add with country code if missing
    if (!phoneNumber.startsWith('+')) {
      formats.add('+$digitsOnly');
      formats.add('+1$digitsOnly'); // Assuming US/Canada if no country code
    }
    
    // Add without country code if present
    if (phoneNumber.startsWith('+1') && digitsOnly.length > 10) {
      formats.add(digitsOnly.substring(1));
    }
    
    return formats.toList();
  }
}
