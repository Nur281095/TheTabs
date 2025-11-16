import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/user.dart';

class ConversationListItem extends StatelessWidget {
  final Map<String, dynamic> conversationData;
  final VoidCallback onTap;
  final bool showUnreadBadge;

  const ConversationListItem({
    required this.conversationData,
    required this.onTap,
    this.showUnreadBadge = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final conversation = conversationData['conversation'] as ConversationModel?;
    final otherUser = conversationData['otherUser'] as UserModel?;
    final unreadCount = conversationData['unreadCount'] as int? ?? 0;

    if (conversation == null) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: otherUser?.profilePhotoUrl != null
                ? NetworkImage(otherUser!.profilePhotoUrl!)
                : null,
            child: otherUser?.profilePhotoUrl == null
                ? Text(
                    otherUser?.displayName?.isNotEmpty == true
                        ? otherUser!.displayName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          // Online status indicator
          if (otherUser?.onlineStatus == 'online')
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUser?.displayName ?? 'Unknown User',
              style: TextStyle(
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.lastActivity != null)
            Text(
              _formatLastActivity(conversation.lastActivity!),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              _getLastMessage(conversationData),
              style: TextStyle(
                color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showUnreadBadge && unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  String _getLastMessage(Map<String, dynamic> conversationData) {
    // Check if there are matching messages from search
    final matchingMessages = conversationData['matchingMessages'] as List?;
    if (matchingMessages != null && matchingMessages.isNotEmpty) {
      final lastMatchingMessage = matchingMessages.first;
      return lastMatchingMessage['content'] ?? 'Media message';
    }

    // Default to a generic last message
    return 'Tap to view conversation';
  }

  String _formatLastActivity(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 6) {
      // More than a week ago - show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      // Show days ago
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      // Show hours ago
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      // Show minutes ago
      return '${difference.inMinutes}m';
    } else {
      // Just now
      return 'now';
    }
  }
}