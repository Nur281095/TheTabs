import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../services/conversation_service.dart';
import '../widgets/conversation_list_item.dart';
import 'chat_screen.dart';

class ConversationsSearchScreen extends StatefulWidget {
  const ConversationsSearchScreen({super.key});

  @override
  State<ConversationsSearchScreen> createState() => _ConversationsSearchScreenState();
}

class _ConversationsSearchScreenState extends State<ConversationsSearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ConversationService _conversationService = ConversationService();
  
  late TabController _tabController;
  
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _unreadConversations = [];
  List<ConversationModel> _recentConversations = [];
  
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'participants', 'messages'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });
    
    if (query.isNotEmpty) {
      _performSearch(query);
    } else {
      setState(() {
        _searchResults.clear();
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      final futures = await Future.wait([
        _conversationService.getUnreadConversations(),
        _conversationService.getConversationsByTimeframe(
          startDate: DateTime.now().subtract(const Duration(days: 7)),
          limit: 30,
        ),
      ]);
      
      setState(() {
        _unreadConversations = futures[0] as List<Map<String, dynamic>>;
        _recentConversations = futures[1] as List<ConversationModel>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading initial data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      List<Map<String, dynamic>> results;
      
      switch (_selectedFilter) {
        case 'participants':
          results = await _conversationService.searchConversationsByParticipant(query);
          break;
        case 'messages':
          results = await _conversationService.searchConversationsByMessage(query);
          break;
        case 'all':
        default:
          results = await _conversationService.searchConversations(query);
          break;
      }
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching conversations: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conversationData) async {
    final conversation = conversationData['conversation'] as ConversationModel?;
    final otherUser = conversationData['otherUser'] as UserModel?;
    
    if (conversation != null && mounted) {
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

  Widget _buildSearchFilters() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Filter:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('participants', 'People'),
                  const SizedBox(width: 8),
                  _buildFilterChip('messages', 'Messages'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
          if (_searchQuery.isNotEmpty) {
            _performSearch(_searchQuery);
          }
        }
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search conversations',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Find chats by person name or message content',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No conversations found for "$_searchQuery"',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const Text(
              'Try a different search term or filter',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return SearchResultItem(
          result: result,
          searchQuery: _searchQuery,
          onTap: () => _openConversation(result),
        );
      },
    );
  }

  Widget _buildUnreadConversations() {
    if (_isLoading && _unreadConversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_unreadConversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_read, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No unread messages',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'All caught up!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        itemCount: _unreadConversations.length,
        itemBuilder: (context, index) {
          final conversationData = _unreadConversations[index];
          return ConversationListItem(
            conversationData: conversationData,
            onTap: () => _openConversation(conversationData),
            showUnreadBadge: true,
          );
        },
      ),
    );
  }

  Widget _buildRecentConversations() {
    if (_isLoading && _recentConversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentConversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No recent conversations',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        itemCount: _recentConversations.length,
        itemBuilder: (context, index) {
          final conversation = _recentConversations[index];
          return FutureBuilder<Map<String, dynamic>?>(
            future: _conversationService.getConversationWithUserDetails(conversation.id),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return ConversationListItem(
                  conversationData: snapshot.data!,
                  onTap: () => _openConversation(snapshot.data!),
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Conversations'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isSearching ? 120 : 70),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              
              // Search Filters (only show when searching)
              if (_isSearching) _buildSearchFilters(),
              
              // Tab Bar (only show when not searching)
              if (!_isSearching)
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Unread'),
                    Tab(text: 'Recent'),
                  ],
                ),
            ],
          ),
        ),
      ),
      body: _isSearching
          ? _buildSearchResults()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUnreadConversations(),
                _buildRecentConversations(),
              ],
            ),
    );
  }
}

// Widget for displaying search results with highlighting
class SearchResultItem extends StatelessWidget {
  final Map<String, dynamic> result;
  final String searchQuery;
  final VoidCallback onTap;

  const SearchResultItem({
    required this.result,
    required this.searchQuery,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final conversation = result['conversation'] as ConversationModel?;
    final otherUser = result['otherUser'] as UserModel?;
    final matchTypes = result['matchTypes'] as List<String>? ?? [];
    final matchingMessages = result['matchingMessages'] as List<MessageModel>? ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: otherUser?.profilePhotoUrl != null
              ? NetworkImage(otherUser!.profilePhotoUrl!)
              : null,
          child: otherUser?.profilePhotoUrl == null
              ? Text(
                  otherUser?.displayName?.isNotEmpty == true
                      ? otherUser!.displayName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUser?.displayName ?? 'Unknown User',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (matchTypes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  matchTypes.contains('participant') ? 'Name' : 'Message',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (matchingMessages.isNotEmpty)
              ...matchingMessages.take(2).map((message) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      children: _highlightSearchTerm(
                        message.content ?? '',
                        searchQuery,
                        Theme.of(context).primaryColor,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            if (conversation?.lastActivity != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatLastActivity(conversation!.lastActivity!),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  List<TextSpan> _highlightSearchTerm(String text, String searchTerm, Color highlightColor) {
    if (searchTerm.isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowerText = text.toLowerCase();
    final lowerSearchTerm = searchTerm.toLowerCase();
    final spans = <TextSpan>[];
    
    int start = 0;
    int index = lowerText.indexOf(lowerSearchTerm);
    
    while (index != -1) {
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: TextStyle(
          backgroundColor: highlightColor.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + searchTerm.length;
      index = lowerText.indexOf(lowerSearchTerm, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    
    return spans;
  }

  String _formatLastActivity(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
