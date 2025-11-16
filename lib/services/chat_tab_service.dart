import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_service.dart';
import '../models/chat_tab.dart';
import '../services/auth_service.dart';

class ChatTabService {
  static final ChatTabService _instance = ChatTabService._internal();
  factory ChatTabService() => _instance;
  ChatTabService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  /// Get all tabs for a conversation
  Stream<List<ChatTabModel>> getConversationTabs(String conversationId) {
    return _firestoreService.getDocumentsStream(
      collection: 'chatTabs',
      where: [['conversationId', '==', conversationId]],
      orderBy: 'tabOrder',
      descending: false,
    ).map((docs) {
      return docs.map((doc) => ChatTabModel.fromMap(doc, doc['id'])).toList();
    });
  }

  /// Get tabs as a future (for one-time fetch)
  Future<List<ChatTabModel>> getConversationTabsFuture(String conversationId) async {
    try {
      final docs = await _firestoreService.getDocuments(
        collection: 'chatTabs',
        where: [['conversationId', '==', conversationId]],
        orderBy: 'tabOrder',
        descending: false,
      );

      return docs.map((doc) => ChatTabModel.fromMap(doc, doc['id'])).toList();
    } catch (e) {
      print('Error getting conversation tabs: $e');
      return [];
    }
  }

  /// Create a new tab
  Future<String?> createTab({
    required String conversationId,
    required String tabName,
    bool isDefault = false,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return null;

      // Get current max tab order
      final existingTabs = await getConversationTabsFuture(conversationId);
      final maxOrder = existingTabs.isEmpty 
          ? 0 
          : existingTabs.map((tab) => tab.tabOrder).reduce((a, b) => a > b ? a : b);

      final tabData = {
        'conversationId': conversationId,
        'tabName': tabName,
        'tabOrder': maxOrder + 1,
        'createdBy': currentUserId,
        'isDefault': isDefault,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      return await _firestoreService.createDocument(
        collection: 'chatTabs',
        data: tabData,
      );
    } catch (e) {
      print('Error creating tab: $e');
      return null;
    }
  }

  /// Update tab name
  Future<bool> updateTabName(String tabId, String newName) async {
    try {
      return await _firestoreService.updateDocument(
        collection: 'chatTabs',
        documentId: tabId,
        data: {
          'tabName': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      print('Error updating tab name: $e');
      return false;
    }
  }

  /// Reorder tabs
  Future<bool> reorderTabs(List<ChatTabModel> tabs) async {
    try {
      final batch = <Map<String, dynamic>>[];

      for (int i = 0; i < tabs.length; i++) {
        batch.add({
          'type': 'update',
          'collection': 'chatTabs',
          'documentId': tabs[i].id,
          'data': {
            'tabOrder': i,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      }

      return await _firestoreService.batchWrite(batch);
    } catch (e) {
      print('Error reordering tabs: $e');
      return false;
    }
  }

  /// Delete a tab (only if not default and has no messages)
  Future<bool> deleteTab(String tabId) async {
    try {
      // Get tab details
      final tabData = await _firestoreService.getDocument(
        collection: 'chatTabs',
        documentId: tabId,
      );

      if (tabData == null) return false;

      final tab = ChatTabModel.fromMap(tabData, tabId);

      // Don't delete default tab
      if (tab.isDefault) {
        print('Cannot delete default tab');
        return false;
      }

      // Check if tab has messages
      final messages = await _firestoreService.getDocuments(
        collection: 'messages',
        where: [['tabId', '==', tabId]],
        limit: 1,
      );

      if (messages.isNotEmpty) {
        print('Cannot delete tab with messages');
        return false;
      }

      // Delete the tab
      return await _firestoreService.deleteDocument(
        collection: 'chatTabs',
        documentId: tabId,
      );
    } catch (e) {
      print('Error deleting tab: $e');
      return false;
    }
  }

  /// Get tab by ID
  Future<ChatTabModel?> getTab(String tabId) async {
    try {
      final tabData = await _firestoreService.getDocument(
        collection: 'chatTabs',
        documentId: tabId,
      );

      if (tabData != null) {
        return ChatTabModel.fromMap(tabData, tabId);
      }
      return null;
    } catch (e) {
      print('Error getting tab: $e');
      return null;
    }
  }

  /// Get default tab for a conversation
  Future<ChatTabModel?> getDefaultTab(String conversationId) async {
    try {
      final tabs = await _firestoreService.getDocuments(
        collection: 'chatTabs',
        where: [
          ['conversationId', '==', conversationId],
          ['isDefault', '==', true]
        ],
        limit: 1,
      );

      if (tabs.isNotEmpty) {
        return ChatTabModel.fromMap(tabs.first, tabs.first['id']);
      }
      return null;
    } catch (e) {
      print('Error getting default tab: $e');
      return null;
    }
  }
}
