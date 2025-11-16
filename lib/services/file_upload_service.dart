import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../services/auth_service.dart';

class FileUploadService {
  static final FileUploadService _instance = FileUploadService._internal();
  factory FileUploadService() => _instance;
  FileUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();

  /// Upload an image file to Firebase Storage
  Future<String?> uploadImage({
    required File imageFile,
    required String conversationId,
    String? caption,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return null;

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = 'image_${timestamp}_${currentUserId}$extension';
      
      // Create storage reference
      final ref = _storage
          .ref()
          .child('conversations')
          .child(conversationId)
          .child('images')
          .child(fileName);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: lookupMimeType(imageFile.path) ?? 'image/jpeg',
        customMetadata: {
          'uploadedBy': currentUserId,
          'uploadedAt': timestamp.toString(),
          'originalName': path.basename(imageFile.path),
          if (caption != null) 'caption': caption,
        },
      );

      // Upload file
      final uploadTask = ref.putFile(imageFile, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Image upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for completion
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Image uploaded successfully: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Upload a file to Firebase Storage
  Future<String?> uploadFile({
    required File file,
    required String conversationId,
    String? caption,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return null;

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path);
      final originalName = path.basenameWithoutExtension(file.path);
      final fileName = '${originalName}_${timestamp}_${currentUserId}$extension';
      
      // Create storage reference
      final ref = _storage
          .ref()
          .child('conversations')
          .child(conversationId)
          .child('files')
          .child(fileName);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: lookupMimeType(file.path) ?? 'application/octet-stream',
        customMetadata: {
          'uploadedBy': currentUserId,
          'uploadedAt': timestamp.toString(),
          'originalName': path.basename(file.path),
          'fileSize': file.lengthSync().toString(),
          if (caption != null) 'caption': caption,
        },
      );

      // Upload file
      final uploadTask = ref.putFile(file, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('File upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      // Wait for completion
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('File uploaded successfully: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  /// Get file metadata from Firebase Storage
  Future<Map<String, dynamic>?> getFileMetadata(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      final metadata = await ref.getMetadata();
      
      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated,
        'updated': metadata.updated,
        'customMetadata': metadata.customMetadata,
      };
    } catch (e) {
      print('Error getting file metadata: $e');
      return null;
    }
  }

  /// Delete file from Firebase Storage
  Future<bool> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('File deleted successfully: $downloadUrl');
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get file extension icon
  static IconData getFileIcon(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    
    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.txt':
        return Icons.text_snippet;
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.archive;
      case '.mp3':
      case '.wav':
      case '.m4a':
        return Icons.music_note;
      case '.mp4':
      case '.mov':
      case '.avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }
}
