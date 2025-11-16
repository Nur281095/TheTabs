import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_service.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class ConversationService {
  static final ConversationService _instance = ConversationService._internal();
  factory ConversationService() => _instance;
  ConversationService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  /// Find existing conversation between two users
  /// Returns conversation ID if exists, null otherwise
  Future<String?> findConversationBetweenUsers(String user1Id, String user2Id) async {
    try {
      // Query for conversations that contain user1Id
      final conversations = await _firestoreService.getDocuments(
        collection: 'conversations',
        where: [['participants', 'array-contains', user1Id]],
        limit: 10, // Get more to check for user2Id
      );

      // Filter client-side to find conversation that contains both users
      for (final conversation in conversations) {
        final participants = List<String>.from(conversation['participants'] ?? []);
        if (participants.contains(user1Id) && participants.contains(user2Id) && participants.length == 2) {
          return conversation['id'];
        }
      }
      
      return null;
    } catch (e) {
      print('Error finding conversation: $e');
      return null;
    }
  }

  /// Create a new conversation between two users
  Future<String?> createConversation(String otherUserId) async {
    try {
      final currentUserId = _authService.currentUserId;
      print('ConversationService: Creating conversation');
      print('ConversationService: Current user ID: $currentUserId');
      print('ConversationService: Other user ID: $otherUserId');
      print('ConversationService: Auth service isSignedIn: ${_authService.isSignedIn}');
      
      if (currentUserId == null) {
        print('ConversationService: ERROR - Current user ID is null');
        return null;
      }

      // Check if conversation already exists
      final existingConversationId = await findConversationBetweenUsers(currentUserId, otherUserId);
      if (existingConversationId != null) {
        return existingConversationId;
      }

      // Ensure consistent participant ordering
      final participants = [currentUserId, otherUserId]..sort();

      final conversationData = {
        'participants': participants,
        'createdBy': currentUserId,
        'lastMessageId': null,
        'lastActivity': FieldValue.serverTimestamp(),
        'user1UnreadCount': 0,
        'user2UnreadCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final conversationId = await _firestoreService.createDocument(
        collection: 'conversations',
        data: conversationData,
      );

      if (conversationId != null) {
        // Create default "General" tab
        await createDefaultTab(conversationId, currentUserId);
      }

      return conversationId;
    } catch (e) {
      print('Error creating conversation: $e');
      return null;
    }
  }

  /// Create default "General" tab for a conversation
  Future<String?> createDefaultTab(String conversationId, String createdBy) async {
    try {
      final tabData = {
        'conversationId': conversationId,
        'tabName': 'General',
        'tabOrder': 0,
        'createdBy': createdBy,
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      return await _firestoreService.createDocument(
        collection: 'chatTabs',
        data: tabData,
      );
    } catch (e) {
      print('Error creating default tab: $e');
      return null;
    }
  }

  /// Get all conversations for current user
  Stream<List<ConversationModel>> getUserConversations() {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestoreService.getDocumentsStream(
      collection: 'conversations',
      where: [['participants', 'array-contains', currentUserId]],
      orderBy: 'lastActivity',
      descending: true,
    ).map((docs) {
      return docs.map((doc) => ConversationModel.fromMap(doc, doc['id'])).toList();
    });
  }

  /// Get conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final conversationData = await _firestoreService.getDocument(
        collection: 'conversations',
        documentId: conversationId,
      );

      if (conversationData != null) {
        return ConversationModel.fromMap(conversationData, conversationId);
      }
      return null;
    } catch (e) {
      print('Error getting conversation: $e');
      return null;
    }
  }

  /// Update conversation's last message and activity
  Future<bool> updateConversationLastMessage({
    required String conversationId,
    required String messageId,
    required String senderId,
  }) async {
    try {
      final conversation = await getConversation(conversationId);
      if (conversation == null) return false;

      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return false;

      // Determine which unread count to increment
      Map<String, dynamic> updateData = {
        'lastMessageId': messageId,
        'lastActivity': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Increment unread count for the recipient
      if (senderId != currentUserId) {
        // Message is from other user, increment current user's unread count
        if (conversation.participants[0] == currentUserId) {
          updateData['user1UnreadCount'] = FieldValue.increment(1);
        } else {
          updateData['user2UnreadCount'] = FieldValue.increment(1);
        }
      } else {
        // Message is from current user, increment other user's unread count
        if (conversation.participants[0] == currentUserId) {
          updateData['user2UnreadCount'] = FieldValue.increment(1);
        } else {
          updateData['user1UnreadCount'] = FieldValue.increment(1);
        }
      }

      return await _firestoreService.updateDocument(
        collection: 'conversations',
        documentId: conversationId,
        data: updateData,
      );
    } catch (e) {
      print('Error updating conversation last message: $e');
      return false;
    }
  }

  /// Mark conversation as read for current user
  Future<bool> markConversationAsRead(String conversationId) async {
    try {
      final conversation = await getConversation(conversationId);
      if (conversation == null) return false;

      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return false;

      // Reset unread count for current user
      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (conversation.participants[0] == currentUserId) {
        updateData['user1UnreadCount'] = 0;
      } else {
        updateData['user2UnreadCount'] = 0;
      }

      return await _firestoreService.updateDocument(
        collection: 'conversations',
        documentId: conversationId,
        data: updateData,
      );
    } catch (e) {
      print('Error marking conversation as read: $e');
      return false;
    }
  }

  /// Get conversation with user details for display
  Future<Map<String, dynamic>?> getConversationWithUserDetails(String conversationId) async {
    try {
      final conversation = await getConversation(conversationId);
      if (conversation == null) return null;

      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return null;

      // Get other participant's details
      final otherUserId = conversation.getOtherParticipantId(currentUserId);
      final otherUserData = await _firestoreService.getUserProfile(userId: otherUserId);
      
      return {
        'conversation': conversation,
        'otherUser': otherUserData != null ? UserModel.fromMap(otherUserData) : null,
        'unreadCount': conversation.getUnreadCountForUser(currentUserId),
      };
    } catch (e) {
      print('Error getting conversation with user details: $e');
      return null;
    }
  }

  /// Delete conversation (soft delete - mark as inactive)
  Future<bool> deleteConversation(String conversationId) async {
    try {
      return await _firestoreService.updateDocument(
        collection: 'conversations',
        documentId: conversationId,
        data: {
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      print('Error deleting conversation: $e');
      return false;
    }
  }

  /// Completely delete conversation and all related data (hard delete)
  Future<bool> deleteConversationCompletely(String conversationId) async {
    try {
      print('Starting complete deletion of conversation: $conversationId');

      // 1. Get all tabs for this conversation
      final tabs = await _firestoreService.getDocuments(
        collection: 'chatTabs',
        where: [['conversationId', '==', conversationId]],
      );

      print('Found ${tabs.length} tabs to delete');

      // 2. Delete all messages in all tabs
      for (final tab in tabs) {
        final tabId = tab['id'];
        if (tabId != null) {
          print('Deleting messages for tab: $tabId');
          
          // Get all messages for this tab
          final messages = await _firestoreService.getDocuments(
            collection: 'messages',
            where: [['tabId', '==', tabId]],
          );

          print('Found ${messages.length} messages to delete for tab $tabId');

          // Delete messages in batches
          const batchSize = 500; // Firestore batch limit
          for (int i = 0; i < messages.length; i += batchSize) {
            final batch = <Map<String, dynamic>>[];
            final endIndex = (i + batchSize < messages.length) ? i + batchSize : messages.length;
            
            for (int j = i; j < endIndex; j++) {
              final messageId = messages[j]['id'];
              if (messageId != null) {
                batch.add({
                  'type': 'delete',
                  'collection': 'messages',
                  'documentId': messageId,
                });
              }
            }

            if (batch.isNotEmpty) {
              await _firestoreService.batchWrite(batch);
              print('Deleted batch of ${batch.length} messages');
            }
          }
        }
      }

      // 3. Delete all tabs
      if (tabs.isNotEmpty) {
        print('Deleting ${tabs.length} tabs');
        final tabBatch = <Map<String, dynamic>>[];
        
        for (final tab in tabs) {
          final tabId = tab['id'];
          if (tabId != null) {
            tabBatch.add({
              'type': 'delete',
              'collection': 'chatTabs',
              'documentId': tabId,
            });
          }
        }

        if (tabBatch.isNotEmpty) {
          await _firestoreService.batchWrite(tabBatch);
          print('Deleted all tabs');
        }
      }

      // 4. Finally, delete the conversation itself
      final conversationDeleted = await _firestoreService.deleteDocument(
        collection: 'conversations',
        documentId: conversationId,
      );

      if (conversationDeleted) {
        print('Conversation deleted successfully');
        return true;
      } else {
        print('Failed to delete conversation document');
        return false;
      }

    } catch (e) {
      print('Error completely deleting conversation: $e');
      return false;
    }
  }

  // SEARCH METHODS

  /// Search conversations by participant name
  Future<List<Map<String, dynamic>>> searchConversationsByParticipant(String searchQuery) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null || searchQuery.trim().isEmpty) return [];

      // First, search for users matching the query
      final matchingUsers = await _userService.searchUsers(searchQuery);
      if (matchingUsers.isEmpty) return [];

      // Get conversations with these users
      final List<Map<String, dynamic>> matchingConversations = [];

      for (final user in matchingUsers) {
        final conversationData = await getConversationWithUserDetails(
          await findConversationBetweenUsers(currentUserId, user.uid) ?? '',
        );
        
        if (conversationData != null) {
          matchingConversations.add({
            ...conversationData,
            'matchType': 'participant',
            'matchedUser': user,
          });
        }
      }

      return matchingConversations;
    } catch (e) {
      print('Error searching conversations by participant: $e');
      return [];
    }
  }

  /// Search conversations by last message content
  Future<List<Map<String, dynamic>>> searchConversationsByMessage(String searchQuery) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null || searchQuery.trim().isEmpty) return [];

      // Get user's conversations
      final conversations = await getUserConversationsFuture();
      final List<Map<String, dynamic>> matchingConversations = [];

      for (final conversation in conversations) {
        // Search for messages in this conversation that match the query
        final matchingMessages = await _searchMessagesInConversation(
          conversation.id, 
          searchQuery,
        );

        if (matchingMessages.isNotEmpty) {
          final conversationData = await getConversationWithUserDetails(conversation.id);
          if (conversationData != null) {
            matchingConversations.add({
              ...conversationData,
              'matchType': 'message',
              'matchingMessages': matchingMessages,
              'lastMatchingMessage': matchingMessages.first,
            });
          }
        }
      }

      // Sort by most recent matching message
      matchingConversations.sort((a, b) {
        final aTime = a['lastMatchingMessage']?['sentAt'] as DateTime?;
        final bTime = b['lastMatchingMessage']?['sentAt'] as DateTime?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return matchingConversations;
    } catch (e) {
      print('Error searching conversations by message: $e');
      return [];
    }
  }

  /// Comprehensive search across all conversation aspects
  Future<List<Map<String, dynamic>>> searchConversations(String searchQuery) async {
    try {
      if (searchQuery.trim().isEmpty) return [];

      final List<Map<String, dynamic>> allResults = [];

      // Search by participant name
      final participantResults = await searchConversationsByParticipant(searchQuery);
      allResults.addAll(participantResults);

      // Search by message content
      final messageResults = await searchConversationsByMessage(searchQuery);
      allResults.addAll(messageResults);

      // Remove duplicates based on conversation ID
      final uniqueResults = <String, Map<String, dynamic>>{};
      for (final result in allResults) {
        final conversationId = result['conversation']?.id ?? '';
        if (conversationId.isNotEmpty) {
          // If we already have this conversation, merge the match types
          if (uniqueResults.containsKey(conversationId)) {
            final existing = uniqueResults[conversationId]!;
            final existingMatchTypes = existing['matchTypes'] as List<String>? ?? [];
            final newMatchType = result['matchType'] as String;
            
            if (!existingMatchTypes.contains(newMatchType)) {
              existingMatchTypes.add(newMatchType);
              existing['matchTypes'] = existingMatchTypes;
            }
          } else {
            result['matchTypes'] = [result['matchType']];
            uniqueResults[conversationId] = result;
          }
        }
      }

      // Sort by relevance and recent activity
      final sortedResults = uniqueResults.values.toList();
      sortedResults.sort((a, b) {
        // Prioritize participant matches over message matches
        final aHasParticipantMatch = (a['matchTypes'] as List).contains('participant');
        final bHasParticipantMatch = (b['matchTypes'] as List).contains('participant');
        
        if (aHasParticipantMatch && !bHasParticipantMatch) return -1;
        if (!aHasParticipantMatch && bHasParticipantMatch) return 1;

        // Then sort by last activity
        final aActivity = a['conversation']?.lastActivity as DateTime?;
        final bActivity = b['conversation']?.lastActivity as DateTime?;
        
        if (aActivity == null && bActivity == null) return 0;
        if (aActivity == null) return 1;
        if (bActivity == null) return -1;
        return bActivity.compareTo(aActivity);
      });

      return sortedResults;
    } catch (e) {
      print('Error in comprehensive conversation search: $e');
      return [];
    }
  }

  /// Search messages within a specific conversation
  Future<List<MessageModel>> _searchMessagesInConversation(
    String conversationId, 
    String searchQuery,
  ) async {
    try {
      // Get all tabs for this conversation
      final tabs = await _firestoreService.getDocuments(
        collection: 'chatTabs',
        where: [['conversationId', '==', conversationId]],
      );

      final List<MessageModel> matchingMessages = [];

      // Search messages in each tab
      for (final tab in tabs) {
        final tabId = tab['id'] ?? '';
        if (tabId.isEmpty) continue;

        // Get recent messages from this tab
        final messages = await _firestoreService.getDocuments(
          collection: 'messages',
          where: [
            ['tabId', '==', tabId],
            ['isDeleted', '==', false],
            ['messageType', '==', 'text'], // Only search text messages
          ],
          orderBy: 'sentAt',
          descending: true,
          limit: 50, // Limit to recent messages for performance
        );

        // Filter messages that contain the search query
        for (final messageData in messages) {
          final content = messageData['content']?.toString().toLowerCase() ?? '';
          if (content.contains(searchQuery.toLowerCase())) {
            matchingMessages.add(MessageModel.fromMap(messageData, messageData['id']));
          }
        }
      }

      // Sort by most recent
      matchingMessages.sort((a, b) => b.sentAt.compareTo(a.sentAt));

      return matchingMessages.take(10).toList(); // Return top 10 matches
    } catch (e) {
      print('Error searching messages in conversation: $e');
      return [];
    }
  }

  /// Get user conversations as a future (for search purposes)
  Future<List<ConversationModel>> getUserConversationsFuture() async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      final docs = await _firestoreService.getDocuments(
        collection: 'conversations',
        where: [['participants', 'array-contains', currentUserId]],
        orderBy: 'lastActivity',
        descending: true,
      );

      return docs.map((doc) => ConversationModel.fromMap(doc, doc['id'])).toList();
    } catch (e) {
      print('Error getting user conversations: $e');
      return [];
    }
  }

  /// Filter conversations by activity timeframe
  Future<List<ConversationModel>> getConversationsByTimeframe({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      List<List<dynamic>> whereConditions = [
        ['participants', 'array-contains', currentUserId]
      ];

      final docs = await _firestoreService.getDocuments(
        collection: 'conversations',
        where: whereConditions,
        orderBy: 'lastActivity',
        descending: true,
        limit: limit,
      );

      List<ConversationModel> conversations = docs
          .map((doc) => ConversationModel.fromMap(doc, doc['id']))
          .toList();

      // Filter by date range client-side (Firestore limitations)
      if (startDate != null || endDate != null) {
        conversations = conversations.where((conv) {
          if (conv.lastActivity == null) return false;
          
          final activity = conv.lastActivity!;
          
          if (startDate != null && activity.isBefore(startDate)) return false;
          if (endDate != null && activity.isAfter(endDate)) return false;
          
          return true;
        }).toList();
      }

      return conversations;
    } catch (e) {
      print('Error getting conversations by timeframe: $e');
      return [];
    }
  }

  /// Get conversations with unread messages only
  Future<List<Map<String, dynamic>>> getUnreadConversations() async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      final conversations = await getUserConversationsFuture();
      final List<Map<String, dynamic>> unreadConversations = [];

      for (final conversation in conversations) {
        final unreadCount = conversation.getUnreadCountForUser(currentUserId);
        if (unreadCount > 0) {
          final conversationData = await getConversationWithUserDetails(conversation.id);
          if (conversationData != null) {
            unreadConversations.add(conversationData);
          }
        }
      }

      return unreadConversations;
    } catch (e) {
      print('Error getting unread conversations: $e');
      return [];
    }
  }

  /// Search conversations with advanced filters
  Future<List<Map<String, dynamic>>> advancedConversationSearch({
    String? participantQuery,
    String? messageQuery,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasUnreadMessages,
    List<String>? participantStatusFilter, // ['online', 'offline', 'away']
    int limit = 20,
  }) async {
    try {
      List<Map<String, dynamic>> results = [];

      // Start with all user conversations
      final allConversations = await getUserConversationsFuture();
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return [];

      for (final conversation in allConversations) {
        bool matches = true;
        final conversationData = await getConversationWithUserDetails(conversation.id);
        if (conversationData == null) continue;

        final otherUser = conversationData['otherUser'] as UserModel?;

        // Filter by participant name
        if (participantQuery != null && participantQuery.isNotEmpty && otherUser != null) {
          final displayName = otherUser.displayName?.toLowerCase() ?? '';
          if (!displayName.contains(participantQuery.toLowerCase())) {
            matches = false;
          }
        }

        // Filter by message content
        if (messageQuery != null && messageQuery.isNotEmpty && matches) {
          final matchingMessages = await _searchMessagesInConversation(
            conversation.id, 
            messageQuery,
          );
          if (matchingMessages.isEmpty) {
            matches = false;
          } else {
            conversationData['matchingMessages'] = matchingMessages;
          }
        }

        // Filter by date range
        if ((startDate != null || endDate != null) && matches) {
          final lastActivity = conversation.lastActivity;
          if (lastActivity != null) {
            if (startDate != null && lastActivity.isBefore(startDate)) matches = false;
            if (endDate != null && lastActivity.isAfter(endDate)) matches = false;
          } else {
            matches = false;
          }
        }

        // Filter by unread status
        if (hasUnreadMessages != null && matches) {
          final unreadCount = conversation.getUnreadCountForUser(currentUserId);
          if (hasUnreadMessages && unreadCount == 0) matches = false;
          if (!hasUnreadMessages && unreadCount > 0) matches = false;
        }

        // Filter by participant status
        if (participantStatusFilter != null && 
            participantStatusFilter.isNotEmpty && 
            matches && 
            otherUser != null) {
          if (!participantStatusFilter.contains(otherUser.onlineStatus)) {
            matches = false;
          }
        }

        if (matches) {
          results.add(conversationData);
        }

        // Respect limit
        if (results.length >= limit) break;
      }

      return results;
    } catch (e) {
      print('Error in advanced conversation search: $e');
      return [];
    }
  }
}
