import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/conversation_service.dart';
// UserListItem widget is defined in this file
import 'chat_screen.dart';

class UsersSearchScreen extends StatefulWidget {
  const UsersSearchScreen({super.key});

  @override
  State<UsersSearchScreen> createState() => _UsersSearchScreenState();
}

class _UsersSearchScreenState extends State<UsersSearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final ConversationService _conversationService = ConversationService();
  
  late TabController _tabController;
  
  List<UserModel> _allUsers = [];
  List<UserModel> _searchResults = [];
  List<UserModel> _onlineUsers = [];
  List<UserModel> _recentUsers = [];
  
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        _userService.getAllUsers(limit: 50),
        _userService.getUsersByStatus('online'),
        _userService.getRecentlyActiveUsers(),
      ]);
      
      setState(() {
        _allUsers = futures[0];
        _onlineUsers = futures[1];
        _recentUsers = futures[2];
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
      final results = await _userService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startConversation(UserModel user) async {
    setState(() => _isLoading = true);
    
    try {
      final conversationId = await _conversationService.createConversation(user.uid);
      
      if (conversationId != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherUser: user,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create conversation')),
        );
      }
    } catch (e) {
      print('Error starting conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error starting conversation')),
      );
    }
    
    setState(() => _isLoading = false);
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
              'Search for users',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Enter a name or phone number to find people',
              style: TextStyle(color: Colors.grey),
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
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_searchQuery"',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return UserListItem(
          user: user,
          onTap: () => _startConversation(user),
          showOnlineStatus: true,
        );
      },
    );
  }

  Widget _buildUserList(List<UserModel> users, String emptyMessage) {
    if (_isLoading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return UserListItem(
            user: user,
            onTap: () => _startConversation(user),
            showOnlineStatus: true,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find People'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone number...',
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
              
              // Tab Bar (only show when not searching)
              if (!_isSearching)
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'All Users'),
                    Tab(text: 'Online'),
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
                _buildUserList(_allUsers, 'No users found'),
                _buildUserList(_onlineUsers, 'No users currently online'),
                _buildUserList(_recentUsers, 'No recently active users'),
              ],
            ),
    );
  }
}

// Helper widget for displaying user list items
class UserListItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final bool showOnlineStatus;

  const UserListItem({
    required this.user,
    required this.onTap,
    this.showOnlineStatus = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.profilePhotoUrl != null
            ? NetworkImage(user.profilePhotoUrl!)
            : null,
        child: user.profilePhotoUrl == null
            ? Text(
                user.displayName?.isNotEmpty == true
                    ? user.displayName![0].toUpperCase()
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(
        user.displayName ?? 'Unknown User',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.phoneNumber),
          if (user.about?.isNotEmpty == true)
            Text(
              user.about!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: showOnlineStatus
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(user.onlineStatus),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.onlineStatus.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'away':
        return Colors.orange;
      case 'offline':
      default:
        return Colors.grey;
    }
  }
}
