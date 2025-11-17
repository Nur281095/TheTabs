import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/message.dart';
import '../models/user.dart';
import '../models/chat_tab.dart';

import '../services/chat_tab_service.dart';
import '../services/conversation_service.dart';
import '../services/message_service.dart';
import '../services/auth_service.dart';
import '../services/file_upload_service.dart';
import '../config/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final UserModel? otherUser;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  List<ChatTabModel> tabs = [];
  int currentTabIndex = 0;
  TextEditingController messageController = TextEditingController();
  ScrollController scrollController = ScrollController();
  ScrollController tabScrollController = ScrollController();
  late TabController tabController;
  bool isLoading = true;
  bool isTyping = false;
  bool isCreatingTab = false;
  bool _isTabControllerInitialized = false;
  
  // Services
  final ChatTabService _chatTabService = ChatTabService();
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final FileUploadService _fileUploadService = FileUploadService();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Data  
  UserModel? _otherUser;
  Map<String, List<MessageModel>> _tabMessages = {};
  
  // Upload states
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadingFileName;

  @override
  void initState() {
    super.initState();
    _otherUser = widget.otherUser;
    _loadConversationData();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    tabScrollController.dispose();
    
    // Safely dispose TabController
    if (_isTabControllerInitialized) {
      try {
        tabController.dispose();
        _isTabControllerInitialized = false;
      } catch (e) {
        // TabController already disposed, ignore
        print('TabController disposal error: $e');
      }
    }
    
    super.dispose();
  }

  Future<void> _loadConversationData() async {
    try {
      setState(() => isLoading = true);
      
      // Load tabs for this conversation
      final conversationTabs = await _chatTabService.getConversationTabsFuture(widget.conversationId);
      
      // Use only the actual tabs (no + tab needed)
      tabs = conversationTabs;
      
      // Initialize tab controller
      tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: 0,
      );
      _isTabControllerInitialized = true;
      
      // Load messages for each tab
      for (final tab in tabs) {
        if (!tab.isAddNewTab) {
          _loadTabMessages(tab.id);
        }
      }
      
      setState(() {
        currentTabIndex = 0;
        isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      print('Error loading conversation data: $e');
      setState(() => isLoading = false);
    }
  }
  
  
  void _loadTabMessages(String tabId) {
    _messageService.getTabMessages(tabId).listen((messages) {
      setState(() {
        _tabMessages[tabId] = messages;
      });
    });
  }

  Future<void> _addNewTab() async {
    if (isCreatingTab) return; // Prevent multiple concurrent tab creations
    
    setState(() {
      isCreatingTab = true;
    });
    
    try {
      // Count real tabs (excluding the + tab)
      final realTabs = tabs.where((tab) => !tab.isAddNewTab).toList();
      final tabName = 'Topic ${realTabs.length + 1}';
      
      // Create new tab
      final newTabId = await _chatTabService.createTab(
        conversationId: widget.conversationId,
        tabName: tabName,
      );
      
      if (newTabId != null) {
        // Reload tabs from database to get the latest data
        final conversationTabs = await _chatTabService.getConversationTabsFuture(widget.conversationId);
        
        // Find the index of the newly created tab
        final newTabIndex = conversationTabs.indexWhere((tab) => tab.id == newTabId);
        
        if (newTabIndex != -1) {
          // Update tabs list with the new tabs
          final newTabs = conversationTabs;
          
          setState(() {
            tabs = newTabs;
            currentTabIndex = newTabIndex;
            
            // Replace TabController safely
            if (_isTabControllerInitialized) {
              final oldController = tabController;
              tabController = TabController(
                length: newTabs.length,
                vsync: this,
                initialIndex: newTabIndex, // Select the newly created tab
              );
              
              // Dispose the old controller after the new one is assigned
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  oldController.dispose();
                } catch (e) {
                  // Controller already disposed, ignore
                  print('Old TabController disposal error: $e');
                }
              });
            } else {
              // First time initialization
              tabController = TabController(
                length: newTabs.length,
                vsync: this,
                initialIndex: newTabIndex,
              );
              _isTabControllerInitialized = true;
            }
          });
          
          // Load messages for new tab
          _loadTabMessages(newTabId);
          
          // Scroll to newly created tab with animation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToSelectedTab(currentTabIndex);
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      print('Error creating new tab: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create new tab. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isCreatingTab = false;
        });
        print('Tab creation process completed. isCreatingTab set to false.');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToSelectedTab(int index) {
    if (!tabScrollController.hasClients || index < 0 || index >= tabs.length) return;
    
    // Calculate approximate position of the tab
    // Each tab width varies by content, but we estimate:
    // Short tabs (~50-80px) + medium tabs (~80-120px) + padding + margin
    const double averageTabWidth = 90.0;
    const double tabMargin = 8.0;
    
    // Calculate target position to center the selected tab in viewport
    final double targetPosition = (averageTabWidth + tabMargin) * index - (MediaQuery.of(context).size.width / 2) + (averageTabWidth / 2);
    final double maxScroll = tabScrollController.position.maxScrollExtent;
    final double minScroll = tabScrollController.position.minScrollExtent;
    
    // Clamp the target position to valid range
    final double clampedPosition = targetPosition.clamp(minScroll, maxScroll);
    
    // Animate to the position
    tabScrollController.animateTo(
      clampedPosition,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar style based on platform
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Platform.isIOS ? Brightness.light : Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildModernAppBar(context),
                if (isLoading)
                  Expanded(child: _buildLoadingState())
                else ...[
                  _buildModernTabBar(),
                  Expanded(child: _buildMessagesList()),
                  _buildModernMessageInput(),
                ],
              ],
            ),
            if (!isLoading)
              Positioned(
                bottom: 100,
                right: 20,
                child: _buildFloatingActionButton(),
              ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: ClipOval(
              child: _otherUser?.profilePhotoUrl != null
                  ? Image.network(
                      _otherUser!.profilePhotoUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _otherUser?.displayName ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isTyping ? 'typing...' : 'last seen recently',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isTyping ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            onSelected: (String value) {
              if (value == 'delete') {
                _showDeleteConversationDialog();
              }
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Delete Conversation',
                      style: TextStyle(
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(
        Icons.person_rounded,
        color: AppColors.textSecondary,
        size: 20,
      ),
    );
  }

  Widget _buildModernTabBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: ListView.builder(
        controller: tabScrollController,
        key: ValueKey(tabs.length),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = currentTabIndex == index;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                currentTabIndex = index;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToSelectedTab(index);
              });
              _scrollToBottom();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 8),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.35)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white.withOpacity(0.25),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isSelected ? 0.15 : 0.08),
                    blurRadius: isSelected ? 12 : 8,
                    offset: Offset(0, isSelected ? 3 : 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  tab.tabName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(isSelected ? 1.0 : 0.85),
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
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
          if (!isCreatingTab) {
            _addNewTab();
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: isCreatingTab
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.9),
                  ),
                ),
              )
            : Icon(
                Icons.add_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 28,
              ),
      ),
    );
  }

  Widget _buildMessagesList() {
    final currentTab = tabs.isNotEmpty && currentTabIndex < tabs.length 
        ? tabs[currentTabIndex] 
        : null;
    
    if (currentTab == null) {
      return _buildEmptyTabState();
    }

    final messages = _tabMessages[currentTab.id] ?? [];

    if (messages.isEmpty) {
      return _buildEmptyTabState();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showDateHeader = index == 0 || 
            (index > 0 && _formatDate(messages[index - 1].sentAt) != _formatDate(message.sentAt));
        
        return Column(
          children: [
            if (showDateHeader) _buildDateHeader(_formatDate(message.sentAt)),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }
  
  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildEmptyTabState() {
    final currentTab = tabs.isNotEmpty && currentTabIndex < tabs.length 
        ? tabs[currentTabIndex] 
        : null;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                Icons.chat_bubble_outline_rounded,
                size: 50,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Start the conversation',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
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
              child: Text(
                'Send your first message to start discussing ${currentTab?.tabName ?? 'this topic'}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            date,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4), // Increased spacing between bubbles
      child: Row(
        mainAxisAlignment: message.senderId == _authService.currentUserId
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.senderId == _authService.currentUserId) 
            Expanded(child: Container()) // Push sent messages to the right
          else
            const SizedBox(width: 8), // Small margin for received messages
          
          Flexible(
            child: Container(
              constraints: _getBubbleConstraints(message),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: message.senderId == _authService.currentUserId
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.2),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.12),
                        ],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: message.senderId == _authService.currentUserId 
                      ? const Radius.circular(20) 
                      : const Radius.circular(6),
                  bottomRight: message.senderId == _authService.currentUserId 
                      ? const Radius.circular(6) 
                      : const Radius.circular(20),
                ),
                border: Border.all(
                  color: message.senderId == _authService.currentUserId
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white.withOpacity(0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _shouldUseIntrinsicWidth(message)
                  ? IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMessageContent(message),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                                        Text(
                            _formatTime(message.sentAt),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          if (message.senderId == _authService.currentUserId) ...[
                            const SizedBox(width: 4),
                            Icon(
                              _getStatusIcon(message),
                              size: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                            ],
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          child: _buildMessageContent(message),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.sentAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            if (message.senderId == _authService.currentUserId) ...[
                              const SizedBox(width: 4),
                              Icon(
                                _getStatusIcon(message),
                                size: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          
          if (message.senderId != _authService.currentUserId) 
            Expanded(child: Container()) // Push received messages to the left
          else
            const SizedBox(width: 8), // Small margin for sent messages
        ],
      ),
    );
  }

  BoxConstraints _getBubbleConstraints(MessageModel message) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // For media messages, use a fixed optimal size
    if (message.messageType == MessageType.image || message.messageType == MessageType.file) {
      return BoxConstraints(
        minWidth: 200,
        maxWidth: screenWidth * 0.75,
      );
    }
    
    // For text messages, calculate dynamic width
    final textLength = message.content?.length ?? 0;
    double minWidth;
    double maxWidth;
    
    if (textLength <= 5) {
      // Very short messages (like "Hi", "OK", etc.)
      minWidth = 80;
      maxWidth = 120;
    } else if (textLength <= 15) {
      // Short messages - force wider bubbles
      minWidth = screenWidth * 0.35;
      maxWidth = screenWidth * 0.55;
    } else if (textLength <= 30) {
      // Medium messages - force even wider
      minWidth = screenWidth * 0.50;
      maxWidth = screenWidth * 0.70;
    } else {
      // Long messages - force maximum width
      minWidth = screenWidth * 0.60;
      maxWidth = screenWidth * 0.80;
    }
    
    return BoxConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
    );
  }

  bool _shouldUseIntrinsicWidth(MessageModel message) {
    // Only use IntrinsicWidth for very short messages and media
    return message.messageType != MessageType.text || (message.content?.length ?? 0) <= 5;
  }

  Widget _buildMessageContent(MessageModel message) {
    switch (message.messageType) {
      case MessageType.text:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: message.isFromCurrentUser(_authService.currentUserId ?? '')
                ? Colors.white
                : const Color(0xFF1A1A1A),
            height: 1.3,
            letterSpacing: -0.1,
          ),
          softWrap: true,
          overflow: TextOverflow.visible,
        );
      case MessageType.image:
        return _buildImageMessage(message);
      case MessageType.file:
        return _buildFileMessage(message);
    }
  }

  Widget _buildImageMessage(MessageModel message) {
    bool isFromCurrentUser = message.isFromCurrentUser(_authService.currentUserId ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((message.content ?? '').isNotEmpty) ...[
          Text(
            message.content ?? '',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: isFromCurrentUser
                  ? Colors.white
                  : const Color(0xFF1A1A1A),
              height: 1.3,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.mediaUrl!,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.image_not_supported_rounded,
                  size: 40,
                  color: Colors.white.withOpacity(0.6),
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileMessage(MessageModel message) {
    final fileName = message.content ?? 'Unknown File';
    final isFromCurrentUser = message.isFromCurrentUser(_authService.currentUserId ?? '');
    
    return InkWell(
      onTap: () => _openFile(message.mediaUrl, fileName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FileUploadService.getFileIcon(fileName),
                    color: Colors.white.withOpacity(0.9),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.95),
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: message.mediaUrl != null 
                            ? _fileUploadService.getFileMetadata(message.mediaUrl!)
                            : null,
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final metadata = snapshot.data!;
                            final size = metadata['size'] as int?;
                            final contentType = metadata['contentType'] as String?;
                            
                            return Text(
                              '${_getFileTypeLabel(contentType ?? '')} • ${size != null ? FileUploadService.formatFileSize(size) : 'Unknown size'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            );
                          }
                          return Text(
                            _getFileTypeFromExtension(fileName),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.download_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFileTypeLabel(String contentType) {
    if (contentType.startsWith('image/')) return 'Image';
    if (contentType.startsWith('video/')) return 'Video';
    if (contentType.startsWith('audio/')) return 'Audio';
    if (contentType.contains('pdf')) return 'PDF Document';
    if (contentType.contains('word') || contentType.contains('document')) return 'Word Document';
    if (contentType.contains('spreadsheet') || contentType.contains('excel')) return 'Spreadsheet';
    if (contentType.contains('presentation') || contentType.contains('powerpoint')) return 'Presentation';
    if (contentType.contains('text')) return 'Text File';
    if (contentType.contains('zip') || contentType.contains('archive')) return 'Archive';
    return 'File';
  }

  String _getFileTypeFromExtension(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.pdf': return 'PDF Document';
      case '.doc':
      case '.docx': return 'Word Document';
      case '.xls':
      case '.xlsx': return 'Spreadsheet';
      case '.ppt':
      case '.pptx': return 'Presentation';
      case '.txt': return 'Text File';
      case '.zip':
      case '.rar':
      case '.7z': return 'Archive';
      case '.mp3':
      case '.wav':
      case '.m4a': return 'Audio File';
      case '.mp4':
      case '.mov':
      case '.avi': return 'Video File';
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif': return 'Image';
      default: return 'File';
    }
  }

  void _openFile(String? fileUrl, String fileName) {
    if (fileUrl == null) {
      _showSnackBar('File URL not available');
      return;
    }

    // TODO: Implement file opening/downloading
    // For now, just show a message
    _showSnackBar('Opening $fileName...');
    
    // You can implement actual file opening here:
    // - For web: window.open(fileUrl)
    // - For mobile: use url_launcher or similar package
    // - For desktop: use url_launcher or file system operations
  }



  IconData _getStatusIcon(MessageModel message) {
    if (message.readAt != null) {
      return Icons.done_all_rounded; // Read
    } else if (message.deliveredAt != null) {
      return Icons.done_all_rounded; // Delivered
    } else {
      return Icons.check_rounded; // Sent
    }
  }
  
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  Widget _buildModernMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Upload progress indicator
            if (_isUploading)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: _uploadProgress,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadingFileName ?? 'Uploading...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                // Attachment button
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isUploading ? null : _showAttachmentOptions,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(_isUploading ? 0.1 : 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.attach_file_rounded,
                          color: Colors.white.withOpacity(_isUploading ? 0.5 : 0.8),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
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
                child: TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                ),
              ),
            ),
              const SizedBox(width: 12),
              Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _isUploading ? null : _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Loading text
            Text(
              'Loading conversation...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we set up your chat',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Shimmer message bubbles
            for (int i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: i.isEven
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.end,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * (0.5 + (i * 0.1)),
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.photo_camera_rounded,
                        label: 'Camera',
                        color: const Color(0xFF007AFF),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromCamera();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: const Color(0xFF30D158),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromGallery();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.insert_drive_file_rounded,
                        label: 'Document',
                        color: const Color(0xFFFF6B47),
                        onTap: () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.videocam_rounded,
                        label: 'Video',
                        color: const Color(0xFFFF9500),
                        onTap: () {
                          Navigator.pop(context);
                          _pickVideo();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.music_note_rounded,
                        label: 'Audio',
                        color: const Color(0xFF9333EA),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAudio();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        color: const Color(0xFF34C759),
                        onTap: () {
                          Navigator.pop(context);
                          _showSnackBar('Location sharing coming soon!');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || currentTabIndex >= tabs.length) return;

    final currentTab = tabs[currentTabIndex];
    messageController.clear();
    
    // Send message through service
    await _messageService.sendTextMessage(
      tabId: currentTab.id,
      content: text,
    );

    _scrollToBottom();
  }

  // Image picking methods
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadAndSendImage(File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image from camera: $e');
      _showSnackBar('Failed to capture image. Please try again.');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _uploadAndSendImage(File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
      _showSnackBar('Failed to select image. Please try again.');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile != null) {
        await _uploadAndSendFile(File(pickedFile.path), MessageType.file);
      }
    } catch (e) {
      print('Error picking video: $e');
      _showSnackBar('Failed to select video. Please try again.');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: null,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        await _uploadAndSendFile(file, MessageType.file);
      }
    } catch (e) {
      print('Error picking file: $e');
      _showSnackBar('Failed to select file. Please try again.');
    }
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        await _uploadAndSendFile(file, MessageType.file);
      }
    } catch (e) {
      print('Error picking audio: $e');
      _showSnackBar('Failed to select audio. Please try again.');
    }
  }

  // Upload and send methods
  Future<void> _uploadAndSendImage(File imageFile) async {
    if (currentTabIndex >= tabs.length || _isUploading) return;

    final currentTab = tabs[currentTabIndex];
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadingFileName = path.basename(imageFile.path);
    });

    try {
      // Simulate upload progress
      _simulateUploadProgress();

      // Upload image to Firebase Storage
      final downloadUrl = await _fileUploadService.uploadImage(
        imageFile: imageFile,
        conversationId: widget.conversationId,
      );

      if (downloadUrl != null) {
        // Send message with uploaded image URL
        await _messageService.sendMediaMessage(
          tabId: currentTab.id,
          messageType: MessageType.image,
          mediaUrl: downloadUrl,
          mediaType: 'image/jpeg',
          content: null, // No caption for now
        );

        _scrollToBottom();
        _showSnackBar('Image sent successfully!');
      } else {
        _showSnackBar('Failed to upload image. Please try again.');
      }
    } catch (e) {
      print('Error uploading image: $e');
      _showSnackBar('Failed to send image. Please try again.');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _uploadingFileName = null;
      });
    }
  }

  Future<void> _uploadAndSendFile(File file, MessageType messageType) async {
    if (currentTabIndex >= tabs.length || _isUploading) return;

    final currentTab = tabs[currentTabIndex];
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadingFileName = path.basename(file.path);
    });

    try {
      // Simulate upload progress
      _simulateUploadProgress();

      // Upload file to Firebase Storage
      final downloadUrl = await _fileUploadService.uploadFile(
        file: file,
        conversationId: widget.conversationId,
      );

      if (downloadUrl != null) {
        // Send message with uploaded file URL
        await _messageService.sendMediaMessage(
          tabId: currentTab.id,
          messageType: messageType,
          mediaUrl: downloadUrl,
          mediaType: path.extension(file.path),
          content: path.basename(file.path),
        );

        _scrollToBottom();
        _showSnackBar('File sent successfully!');
      } else {
        _showSnackBar('Failed to upload file. Please try again.');
      }
    } catch (e) {
      print('Error uploading file: $e');
      _showSnackBar('Failed to send file. Please try again.');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _uploadingFileName = null;
      });
    }
  }

  // Simulate upload progress for better UX
  void _simulateUploadProgress() {
    final duration = 100; // milliseconds per step
    var progress = 0.0;
    
    Timer.periodic(Duration(milliseconds: duration), (timer) {
      if (!_isUploading || progress >= 1.0) {
        timer.cancel();
        return;
      }
      
      progress += 0.02; // Increment by 2%
      if (mounted) {
        setState(() {
          _uploadProgress = progress.clamp(0.0, 0.95); // Stop at 95% until real upload completes
        });
      }
    });
  }

  // Removed simulation methods - using real Firebase data now

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF3B30),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Conversation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this conversation with ${_otherUser?.displayName ?? 'this user'}?',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF3B30).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF3B30),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will permanently delete all messages, tabs, and conversation history.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteConversation();
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversation() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );

      // Delete the conversation and all related data
      final ConversationService conversationService = ConversationService();
      final success = await conversationService.deleteConversationCompletely(widget.conversationId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        // Navigate back to conversations screen
        if (mounted) {
          Navigator.pop(context);
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation deleted successfully'),
              backgroundColor: Color(0xFF34C759),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          _showSnackBar('Failed to delete conversation. Please try again.');
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      
      print('Error deleting conversation: $e');
      if (mounted) {
        _showSnackBar('An error occurred while deleting the conversation.');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
      ),
    );
  }
}
