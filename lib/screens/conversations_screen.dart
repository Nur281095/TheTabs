import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/conversation.dart';
import '../models/user.dart';
import '../widgets/conversation_list_item.dart';
import 'users_list_screen.dart';

import 'user_profile_screen.dart';
import 'chat_screen.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> allConversations = [];
  List<Map<String, dynamic>> filteredConversations = [];
  bool isLoading = true;
  bool isSearchMode = false;
  TextEditingController searchController = TextEditingController();
  
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  
  final ConversationService _conversationService = ConversationService();
  final AuthService _authService = AuthService();
  
  StreamSubscription<List<ConversationModel>>? _conversationsSubscription;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    searchController.addListener(_filterConversations);
    
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    searchController.removeListener(_filterConversations);
    searchController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _loadConversations() {
    setState(() => isLoading = true);
    
    // Cancel existing subscription if any
    _conversationsSubscription?.cancel();
    
    _conversationsSubscription = _conversationService.getUserConversations().listen(
      (conversations) async {
        final conversationsWithDetails = <Map<String, dynamic>>[];
        
        for (final conversation in conversations) {
          final details = await _conversationService.getConversationWithUserDetails(conversation.id);
          if (details != null) {
            conversationsWithDetails.add(details);
          }
        }
        
        if (mounted) {
          setState(() {
            allConversations = conversationsWithDetails;
            filteredConversations = allConversations;
            isLoading = false;
          });
        }
      },
      onError: (error) {
        print('Error loading conversations: $error');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      },
    );
  }

  void _refreshConversations() {
    setState(() {
      isLoading = true;
    });
    _loadConversations();
  }

  void _filterConversations() {
    final query = searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        filteredConversations = allConversations;
      } else {
        filteredConversations = allConversations.where((conversationData) {
          final otherUser = conversationData['otherUser'] as UserModel?;
          final userName = otherUser?.displayName?.toLowerCase() ?? '';
          final userAbout = otherUser?.about?.toLowerCase() ?? '';
          final userPhone = otherUser?.phoneNumber.toLowerCase() ?? '';
          
          // Search in user name, about, and phone number
          return userName.contains(query) || 
                 userAbout.contains(query) || 
                 userPhone.contains(query);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      isSearchMode = !isSearchMode;
    });
    
    if (isSearchMode) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      searchController.clear();
      _filterConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar style based on platform
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Platform.isIOS ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 0.6, 1.0],
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
              Color(0xFF667EEA),
              Color(0xFF9333EA),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(context),
              _buildSearchSection(),
              Expanded(child: _buildConversationsList()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      height: Platform.isIOS ? 44.0 : 56.0, // Native platform heights
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          // Profile button with glassmorphism effect
          Container(
            margin: const EdgeInsets.only(left: 8, right: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserProfileScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://picsum.photos/150/150?random=999',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Title with modern typography
          Expanded(
            child: Text(
              'Messages',
              style: TextStyle(
                color: Colors.white,
                fontSize: Platform.isIOS ? 17.0 : 20.0,
                fontWeight: FontWeight.w600,
                letterSpacing: Platform.isIOS ? -0.4 : -0.2,
                height: 1.2,
              ),
            ),
          ),
          // Search button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _toggleSearch,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSearchMode 
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isSearchMode ? Icons.close_rounded : Icons.search_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UsersListScreen(),
            ),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(
          Icons.add_rounded,
          color: Colors.white.withOpacity(0.9),
          size: 28,
        ),
      ),
    );
  }

  SnackBar _buildCustomSnackBar(String message) {
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.white.withOpacity(0.2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(20),
    );
  }

  Widget _buildSearchSection() {
    if (!isSearchMode) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        alignment: Alignment.centerLeft,
        child: Text(
          'Recent conversations',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search title
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Search conversations',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
          // Modern search bar with glassmorphism
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              autofocus: isSearchMode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name or message...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          searchController.clear();
                          _filterConversations();
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 18,
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (filteredConversations.isEmpty && isSearchMode && searchController.text.isNotEmpty) {
      return _buildNoSearchResults();
    }

    if (filteredConversations.isEmpty && !isSearchMode) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshConversations();
      },
      color: Colors.white,
      backgroundColor: Colors.white.withOpacity(0.2),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: filteredConversations.length,
        itemBuilder: (context, index) {
          final conversationData = filteredConversations[index];
          return _buildModernConversationItem(conversationData, index);
        },
      ),
    );
  }

  Widget _buildModernConversationItem(Map<String, dynamic> conversationData, int index) {
    final conversation = conversationData['conversation'] as ConversationModel?;
    final otherUser = conversationData['otherUser'] as UserModel?;
    final unreadCount = conversationData['unreadCount'] as int? ?? 0;

    if (conversation == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(
        top: index == 0 ? 0 : 8,
        bottom: index == filteredConversations.length - 1 ? 0 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onConversationTap(conversationData),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildModernUserAvatar(otherUser),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and date row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              otherUser?.displayName ?? 'Unknown User',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (conversation.lastActivity != null)
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              child: Text(
                                _formatLastActivity(conversation.lastActivity!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.6),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Message and unread count row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getLastMessage(conversationData),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                                color: unreadCount > 0 
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.white.withOpacity(0.7),
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C851).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00C851).withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Chat arrow indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.7),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernUserAvatar(UserModel? user) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: user?.profilePhotoUrl != null
                ? Image.network(
                    user!.profilePhotoUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatarContent(user);
                    },
                  )
                : _buildDefaultAvatarContent(user),
          ),
        ),
        if (user?.onlineStatus == 'online')
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF00C851),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C851).withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatarContent(UserModel? user) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user?.displayName?.isNotEmpty == true
              ? user!.displayName![0].toUpperCase()
              : '?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          for (int i = 0; i < 6; i++)
            Container(
              margin: EdgeInsets.only(bottom: i < 5 ? 16 : 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Shimmer avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name shimmer
                        Container(
                          height: 18,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Message shimmer
                        Container(
                          height: 14,
                          width: MediaQuery.of(context).size.width * 0.6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time shimmer
                  Container(
                    height: 12,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Beautiful empty state icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 60,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            // Title
            const Text(
              'No Conversations Found',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              'Start a conversation and connect\nwith your friends and colleagues',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w400,
                height: 1.5,
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Start chat button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UsersListScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Start New Chat',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Beautiful empty state icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 50,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Text(
              'No Results Found',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              'Try searching with different keywords\nor check your spelling',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onConversationTap(Map<String, dynamic> conversationData) {
    final conversation = conversationData['conversation'] as ConversationModel?;
    final otherUser = conversationData['otherUser'] as UserModel?;
    
    if (conversation != null) {
      // Mark conversation as read
      _conversationService.markConversationAsRead(conversation.id);
      
      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversation.id,
            otherUser: otherUser,
          ),
        ),
      );
    }
  }
}
