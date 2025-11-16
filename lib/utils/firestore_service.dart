import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // Use the specific database ID for the standard database
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'b303e',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Generic CRUD Operations

  /// Create a new document with retry logic
  /// [collection] - Collection name
  /// [data] - Document data as Map
  /// [documentId] - Optional custom document ID, if null auto-generated
  Future<String?> createDocument({
    required String collection,
    required Map<String, dynamic> data,
    String? documentId,
  }) async {
    const maxRetries = 3;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('FirestoreService: Creating document in collection: $collection (attempt $attempt/$maxRetries)');
        print('FirestoreService: Document ID: $documentId');
        print('FirestoreService: Data: $data');
        
        // Add server timestamp
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        DocumentReference docRef;
        if (documentId != null) {
          docRef = _firestore.collection(collection).doc(documentId);
          print('FirestoreService: Setting document with custom ID...');
          await docRef.set(data).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Firestore operation timeout');
            },
          );
          print('FirestoreService: Document set successfully');
        } else {
          print('FirestoreService: Adding document with auto-generated ID...');
          docRef = await _firestore.collection(collection).add(data).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Firestore operation timeout');
            },
          );
          print('FirestoreService: Document added successfully');
        }
        
        print('FirestoreService: Document created with ID: ${docRef.id}');
        return docRef.id;
      } catch (e) {
        print('FirestoreService: Error creating document (attempt $attempt/$maxRetries): $e');
        
        if (attempt < maxRetries && 
           (e.toString().contains('unavailable') || 
            e.toString().contains('timeout') ||
            e.toString().contains('deadline-exceeded'))) {
          print('FirestoreService: Retrying in ${attempt * 2} seconds...');
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        
        print('FirestoreService: Final error after $attempt attempts: $e');
        print('FirestoreService: Stack trace: ${StackTrace.current}');
        return null;
      }
    }
    
    return null;
  }

  /// Read a single document by ID
  /// [collection] - Collection name
  /// [documentId] - Document ID
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id; // Add document ID to data
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting document: $e');
      return null;
    }
  }

  /// Read multiple documents with optional filtering
  /// [collection] - Collection name
  /// [orderBy] - Field to order by (optional)
  /// [descending] - Order direction (default: false)
  /// [limit] - Maximum number of documents (optional)
  /// [where] - List of where conditions [[field, operator, value], ...]
  Future<List<Map<String, dynamic>>> getDocuments({
    required String collection,
    String? orderBy,
    bool descending = false,
    int? limit,
    List<List<dynamic>>? where,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      // Apply where conditions
      if (where != null) {
        for (var condition in where) {
          if (condition.length == 3) {
            final field = condition[0] as String;
            final operator = condition[1] as String;
            final value = condition[2];
            
            switch (operator) {
              case '==':
                query = query.where(field, isEqualTo: value);
                break;
              case '!=':
                query = query.where(field, isNotEqualTo: value);
                break;
              case '<':
                query = query.where(field, isLessThan: value);
                break;
              case '<=':
                query = query.where(field, isLessThanOrEqualTo: value);
                break;
              case '>':
                query = query.where(field, isGreaterThan: value);
                break;
              case '>=':
                query = query.where(field, isGreaterThanOrEqualTo: value);
                break;
              case 'array-contains':
                query = query.where(field, arrayContains: value);
                break;
              case 'array-contains-any':
                query = query.where(field, arrayContainsAny: value);
                break;
              case 'in':
                query = query.where(field, whereIn: value);
                break;
              case 'not-in':
                query = query.where(field, whereNotIn: value);
                break;
              default:
                query = query.where(field, isEqualTo: value);
            }
          }
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID to data
        return data;
      }).toList();
    } catch (e) {
      print('Error getting documents: $e');
      return [];
    }
  }

  /// Update a document
  /// [collection] - Collection name
  /// [documentId] - Document ID
  /// [data] - Updated data as Map
  Future<bool> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Add server timestamp
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(collection).doc(documentId).update(data);
      return true;
    } catch (e) {
      print('Error updating document: $e');
      return false;
    }
  }

  /// Delete a document
  /// [collection] - Collection name
  /// [documentId] - Document ID
  Future<bool> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
      return true;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }

  /// Get real-time updates for a collection
  /// [collection] - Collection name
  /// [orderBy] - Field to order by (optional)
  /// [descending] - Order direction (default: false)
  /// [limit] - Maximum number of documents (optional)
  /// [where] - List of where conditions [[field, operator, value], ...]
  Stream<List<Map<String, dynamic>>> getDocumentsStream({
    required String collection,
    String? orderBy,
    bool descending = false,
    int? limit,
    List<List<dynamic>>? where,
  }) {
    try {
      Query query = _firestore.collection(collection);

      // Apply where conditions
      if (where != null) {
        for (var condition in where) {
          if (condition.length == 3) {
            final field = condition[0] as String;
            final operator = condition[1] as String;
            final value = condition[2];
            
            switch (operator) {
              case '==':
                query = query.where(field, isEqualTo: value);
                break;
              case '!=':
                query = query.where(field, isNotEqualTo: value);
                break;
              case '<':
                query = query.where(field, isLessThan: value);
                break;
              case '<=':
                query = query.where(field, isLessThanOrEqualTo: value);
                break;
              case '>':
                query = query.where(field, isGreaterThan: value);
                break;
              case '>=':
                query = query.where(field, isGreaterThanOrEqualTo: value);
                break;
              case 'array-contains':
                query = query.where(field, arrayContains: value);
                break;
              case 'array-contains-any':
                query = query.where(field, arrayContainsAny: value);
                break;
              case 'in':
                query = query.where(field, whereIn: value);
                break;
              case 'not-in':
                query = query.where(field, whereNotIn: value);
                break;
              default:
                query = query.where(field, isEqualTo: value);
            }
          }
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      return query.snapshots().map((querySnapshot) {
        return querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Add document ID to data
          return data;
        }).toList();
      }).handleError((error) {
        print('Firestore stream error: $error');
        // Return empty list on permission denied or other errors
        if (error.toString().contains('permission-denied')) {
          print('Permission denied - user may have signed out');
          return <Map<String, dynamic>>[];
        }
        throw error;
      });
    } catch (e) {
      print('Error getting documents stream: $e');
      return Stream.value([]);
    }
  }

  /// Get real-time updates for a single document
  /// [collection] - Collection name
  /// [documentId] - Document ID
  Stream<Map<String, dynamic>?> getDocumentStream({
    required String collection,
    required String documentId,
  }) {
    try {
      return _firestore.collection(collection).doc(documentId).snapshots().map((doc) {
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id; // Add document ID to data
          return data;
        }
        return null;
      }).handleError((error) {
        print('Firestore document stream error: $error');
        // Return null on permission denied or other errors
        if (error.toString().contains('permission-denied')) {
          print('Permission denied - user may have signed out');
          return null;
        }
        throw error;
      });
    } catch (e) {
      print('Error getting document stream: $e');
      return Stream.value(null);
    }
  }

  // Batch Operations

  /// Batch write multiple operations
  /// [operations] - List of operations: [{'type': 'create/update/delete', 'collection': '', 'documentId': '', 'data': {}}]
  Future<bool> batchWrite(List<Map<String, dynamic>> operations) async {
    try {
      final batch = _firestore.batch();

      for (var operation in operations) {
        final type = operation['type'] as String;
        final collection = operation['collection'] as String;
        final documentId = operation['documentId'] as String?;
        final data = operation['data'] as Map<String, dynamic>?;

        DocumentReference docRef;

        switch (type) {
          case 'create':
            if (documentId != null) {
              docRef = _firestore.collection(collection).doc(documentId);
            } else {
              docRef = _firestore.collection(collection).doc();
            }
            if (data != null) {
              data['createdAt'] = FieldValue.serverTimestamp();
              data['updatedAt'] = FieldValue.serverTimestamp();
              batch.set(docRef, data);
            }
            break;

          case 'update':
            if (documentId != null && data != null) {
              docRef = _firestore.collection(collection).doc(documentId);
              data['updatedAt'] = FieldValue.serverTimestamp();
              batch.update(docRef, data);
            }
            break;

          case 'delete':
            if (documentId != null) {
              docRef = _firestore.collection(collection).doc(documentId);
              batch.delete(docRef);
            }
            break;
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error in batch write: $e');
      return false;
    }
  }

  // User-specific Operations

  /// Create user profile
  /// [userId] - User ID
  /// [userData] - User data
  Future<bool> createUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      print('FirestoreService: Creating user profile for userId: $userId');
      print('FirestoreService: User data: $userData');
      
      final docId = await createDocument(
        collection: 'users',
        documentId: userId,
        data: userData,
      );
      
      print('FirestoreService: Document creation result: $docId');
      return docId != null;
    } catch (e) {
      print('FirestoreService: Error creating user profile: $e');
      return false;
    }
  }

  /// Get user profile
  /// [userId] - User ID
  Future<Map<String, dynamic>?> getUserProfile({required String userId}) async {
    return await getDocument(collection: 'users', documentId: userId);
  }

  /// Update user profile
  /// [userId] - User ID
  /// [userData] - Updated user data
  Future<bool> updateUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    return await updateDocument(
      collection: 'users',
      documentId: userId,
      data: userData,
    );
  }

  // Chat-specific Operations

  /// Create a new conversation
  /// [participants] - List of user IDs
  /// [conversationData] - Additional conversation data
  Future<String?> createConversation({
    required List<String> participants,
    Map<String, dynamic>? conversationData,
  }) async {
    final data = {
      'participants': participants,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'isActive': true,
      ...?conversationData,
    };

    return await createDocument(collection: 'conversations', data: data);
  }

  /// Get user conversations
  /// [userId] - User ID
  Future<List<Map<String, dynamic>>> getUserConversations({
    required String userId,
  }) async {
    return await getDocuments(
      collection: 'conversations',
      where: [['participants', 'array-contains', userId]],
      orderBy: 'lastMessageTime',
      descending: true,
    );
  }

  /// Send a message
  /// [conversationId] - Conversation ID
  /// [messageData] - Message data
  Future<String?> sendMessage({
    required String conversationId,
    required Map<String, dynamic> messageData,
  }) async {
    // Create message
    final messageId = await createDocument(
      collection: 'conversations/$conversationId/messages',
      data: messageData,
    );

    // Update conversation with last message
    if (messageId != null) {
      await updateDocument(
        collection: 'conversations',
        documentId: conversationId,
        data: {
          'lastMessage': messageData['content'] ?? '',
          'lastMessageTime': FieldValue.serverTimestamp(),
        },
      );
    }

    return messageId;
  }

  /// Get messages for a conversation
  /// [conversationId] - Conversation ID
  /// [limit] - Number of messages to fetch
  Future<List<Map<String, dynamic>>> getMessages({
    required String conversationId,
    int limit = 50,
  }) async {
    return await getDocuments(
      collection: 'conversations/$conversationId/messages',
      orderBy: 'createdAt',
      descending: true,
      limit: limit,
    );
  }

  /// Get real-time messages stream
  /// [conversationId] - Conversation ID
  /// [limit] - Number of messages to fetch
  Stream<List<Map<String, dynamic>>> getMessagesStream({
    required String conversationId,
    int limit = 50,
  }) {
    return getDocumentsStream(
      collection: 'conversations/$conversationId/messages',
      orderBy: 'createdAt',
      descending: true,
      limit: limit,
    );
  }

  // Search Operations

  /// Search documents by field value
  /// [collection] - Collection name
  /// [field] - Field to search in
  /// [searchTerm] - Search term
  Future<List<Map<String, dynamic>>> searchDocuments({
    required String collection,
    required String field,
    required String searchTerm,
  }) async {
    try {
      // Firestore doesn't support full-text search, this is a basic implementation
      // For better search, consider using Algolia or ElasticSearch
      final querySnapshot = await _firestore
          .collection(collection)
          .where(field, isGreaterThanOrEqualTo: searchTerm)
          .where(field, isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error searching documents: $e');
      return [];
    }
  }

  // Utility Methods

  /// Check if document exists
  /// [collection] - Collection name
  /// [documentId] - Document ID
  Future<bool> documentExists({
    required String collection,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(documentId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking document existence: $e');
      return false;
    }
  }

  /// Get collection size
  /// [collection] - Collection name
  Future<int> getCollectionSize({required String collection}) async {
    try {
      final querySnapshot = await _firestore.collection(collection).get();
      return querySnapshot.size;
    } catch (e) {
      print('Error getting collection size: $e');
      return 0;
    }
  }
}
