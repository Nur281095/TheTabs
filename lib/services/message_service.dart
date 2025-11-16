import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_service.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/conversation_service.dart';
import '../services/topic_detection_service.dart';

class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final ConversationService _conversationService = ConversationService();
  final TopicDetectionService _topicDetectionService = TopicDetectionService();

  /// Get messages for a specific tab
  Stream<List<MessageModel>> getTabMessages(String tabId) {
    return _firestoreService.getDocumentsStream(
      collection: 'messages',
      where: [
        ['tabId', '==', tabId],
        ['isDeleted', '==', false]
      ],
      orderBy: 'messageOrder',
      descending: false,
    ).map((docs) {
      return docs.map((doc) => MessageModel.fromMap(doc, doc['id'])).toList();
    });
  }

  /// Get messages as a future (for pagination)
  Future<List<MessageModel>> getTabMessagesFuture(
    String tabId, {
    int limit = 50,
    int? startAfterOrder,
  }) async {
    try {
      List<List<dynamic>> whereConditions = [
        ['tabId', '==', tabId],
        ['isDeleted', '==', false]
      ];

      if (startAfterOrder != null) {
        whereConditions.add(['messageOrder', '>', startAfterOrder]);
      }

      final docs = await _firestoreService.getDocuments(
        collection: 'messages',
        where: whereConditions,
        orderBy: 'messageOrder',
        descending: false,
        limit: limit,
      );

      return docs.map((doc) => MessageModel.fromMap(doc, doc['id'])).toList();
    } catch (e) {
      print('Error getting tab messages: $e');
      return [];
    }
  }

  /// Send a text message
  Future<String?> sendTextMessage({
    required String tabId,
    required String content,
    String? replyToMessageId,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return null;

      // Get next message order
      final nextOrder = await _getNextMessageOrder(tabId);

      final messageData = {
        'tabId': tabId,
        'senderId': currentUserId,
        'messageType': 'text',
        'content': content,
        'mediaUrl': null,
        'mediaType': null,
        'replyToMessageId': replyToMessageId,
        'sentAt': FieldValue.serverTimestamp(),
        'deliveredAt': null,
        'readAt': null,
        'isDeleted': false,
        'messageOrder': nextOrder,
      };

      final messageId = await _firestoreService.createDocument(
        collection: 'messages',
        data: messageData,
      );

      if (messageId != null) {
        // Update conversation last message
        await _updateConversationAfterMessage(tabId, messageId, currentUserId);
        
        // Mark message as delivered immediately (for demo purposes)
        await markMessageAsDelivered(messageId);
        
        // Trigger topic detection (non-blocking)
        _triggerTopicDetection(tabId);
      }

      return messageId;
    } catch (e) {
      print('Error sending text message: $e');
      return null;
    }
  }

  /// Send a media message (image/file)
  Future<String?> sendMediaMessage({
    required String tabId,
    required MessageType messageType,
    required String mediaUrl,
    required String mediaType,
    String? content, // Optional caption
    String? replyToMessageId,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return null;

      // Get next message order
      final nextOrder = await _getNextMessageOrder(tabId);

      final messageData = {
        'tabId': tabId,
        'senderId': currentUserId,
        'messageType': messageType.toString().split('.').last,
        'content': content,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'replyToMessageId': replyToMessageId,
        'sentAt': FieldValue.serverTimestamp(),
        'deliveredAt': null,
        'readAt': null,
        'isDeleted': false,
        'messageOrder': nextOrder,
      };

      final messageId = await _firestoreService.createDocument(
        collection: 'messages',
        data: messageData,
      );

      if (messageId != null) {
        // Update conversation last message
        await _updateConversationAfterMessage(tabId, messageId, currentUserId);
        
        // Mark message as delivered immediately (for demo purposes)
        await markMessageAsDelivered(messageId);
      }

      return messageId;
    } catch (e) {
      print('Error sending media message: $e');
      return null;
    }
  }

  /// Get next message order for a tab
  Future<int> _getNextMessageOrder(String tabId) async {
    try {
      final messages = await _firestoreService.getDocuments(
        collection: 'messages',
        where: [['tabId', '==', tabId]],
        orderBy: 'messageOrder',
        descending: true,
        limit: 1,
      );

      if (messages.isNotEmpty) {
        return (messages.first['messageOrder'] ?? 0) + 1;
      }
      return 1;
    } catch (e) {
      print('Error getting next message order: $e');
      return 1;
    }
  }

  /// Update conversation after sending a message
  Future<void> _updateConversationAfterMessage(
    String tabId,
    String messageId,
    String senderId,
  ) async {
    try {
      // Get tab to find conversation ID
      final tabData = await _firestoreService.getDocument(
        collection: 'chatTabs',
        documentId: tabId,
      );

      if (tabData != null) {
        final conversationId = tabData['conversationId'];
        await _conversationService.updateConversationLastMessage(
          conversationId: conversationId,
          messageId: messageId,
          senderId: senderId,
        );
      }
    } catch (e) {
      print('Error updating conversation after message: $e');
    }
  }

  /// Mark message as delivered
  Future<bool> markMessageAsDelivered(String messageId) async {
    try {
      return await _firestoreService.updateDocument(
        collection: 'messages',
        documentId: messageId,
        data: {
          'deliveredAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      print('Error marking message as delivered: $e');
      return false;
    }
  }

  /// Mark message as read
  Future<bool> markMessageAsRead(String messageId) async {
    try {
      return await _firestoreService.updateDocument(
        collection: 'messages',
        documentId: messageId,
        data: {
          'readAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      print('Error marking message as read: $e');
      return false;
    }
  }

  /// Mark all messages in a tab as read for current user
  Future<bool> markTabMessagesAsRead(String tabId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return false;

      // Get unread messages from other users
      final unreadMessages = await _firestoreService.getDocuments(
        collection: 'messages',
        where: [
          ['tabId', '==', tabId],
          ['senderId', '!=', currentUserId],
          ['readAt', '==', null],
          ['isDeleted', '==', false]
        ],
      );

      if (unreadMessages.isEmpty) return true;

      // Create batch update
      final batch = <Map<String, dynamic>>[];
      for (final message in unreadMessages) {
        batch.add({
          'type': 'update',
          'collection': 'messages',
          'documentId': message['id'],
          'data': {
            'readAt': FieldValue.serverTimestamp(),
          },
        });
      }

      return await _firestoreService.batchWrite(batch);
    } catch (e) {
      print('Error marking tab messages as read: $e');
      return false;
    }
  }

  /// Delete message (soft delete)
  Future<bool> deleteMessage(String messageId) async {
    try {
      return await _firestoreService.updateDocument(
        collection: 'messages',
        documentId: messageId,
        data: {
          'isDeleted': true,
          'content': null, // Clear content
          'mediaUrl': null, // Clear media
        },
      );
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Get message by ID
  Future<MessageModel?> getMessage(String messageId) async {
    try {
      final messageData = await _firestoreService.getDocument(
        collection: 'messages',
        documentId: messageId,
      );

      if (messageData != null) {
        return MessageModel.fromMap(messageData, messageId);
      }
      return null;
    } catch (e) {
      print('Error getting message: $e');
      return null;
    }
  }

  /// Search messages in a tab
  Future<List<MessageModel>> searchMessagesInTab(
    String tabId,
    String searchQuery,
  ) async {
    try {
      // Note: Firestore doesn't support full-text search
      // This is a basic implementation using contains
      final messages = await _firestoreService.getDocuments(
        collection: 'messages',
        where: [
          ['tabId', '==', tabId],
          ['isDeleted', '==', false],
          ['messageType', '==', 'text'],
        ],
        orderBy: 'messageOrder',
        descending: true,
        limit: 100, // Limit search results
      );

      // Filter results client-side (for basic search)
      final filteredMessages = messages.where((message) {
        final content = message['content']?.toString().toLowerCase() ?? '';
        return content.contains(searchQuery.toLowerCase());
      }).toList();

      return filteredMessages.map((doc) => MessageModel.fromMap(doc, doc['id'])).toList();
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }

  /// Get unread message count for a tab
  Future<int> getUnreadMessageCount(String tabId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return 0;

      final unreadMessages = await _firestoreService.getDocuments(
        collection: 'messages',
        where: [
          ['tabId', '==', tabId],
          ['senderId', '!=', currentUserId],
          ['readAt', '==', null],
          ['isDeleted', '==', false]
        ],
      );

      return unreadMessages.length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  /// Trigger topic detection for a tab (non-blocking)
  void _triggerTopicDetection(String tabId) {
    // Run in background without awaiting
    Future.microtask(() async {
      try {
        final shouldAnalyze = await _topicDetectionService.shouldAnalyzeTab(tabId);
        if (shouldAnalyze) {
          await _topicDetectionService.analyzeAndRenameTab(tabId);
        }
      } catch (e) {
        print('Error triggering topic detection: $e');
      }
    });
  }
}
