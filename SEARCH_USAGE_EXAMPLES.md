# 🔍 Search Implementation Examples

This document shows how to use the comprehensive search functionality for users and conversations.

## 📱 UserService Search Methods

### 1. Basic User Search
```dart
final userService = UserService();

// Search by name or phone number
final results = await userService.searchUsers('John');
// Results are sorted by relevance: exact matches first, then online users
```

### 2. Get Users by Status
```dart
// Get only online users
final onlineUsers = await userService.getUsersByStatus('online');

// Get away users
final awayUsers = await userService.getUsersByStatus('away');

// Get offline users
final offlineUsers = await userService.getUsersByStatus('offline');
```

### 3. Advanced User Search with Filters
```dart
final results = await userService.advancedUserSearch(
  nameQuery: 'John',
  statusFilter: ['online', 'away'], // Only online or away users
  isAvailable: true, // Only available users
  limit: 10,
);
```

### 4. Get Recently Active Users
```dart
// Users active in the last 24 hours
final recentUsers = await userService.getRecentlyActiveUsers();
```

## 💬 ConversationService Search Methods

### 1. Search by Participant Name
```dart
final conversationService = ConversationService();

// Find conversations with users named "Alice"
final results = await conversationService.searchConversationsByParticipant('Alice');
// Returns List<Map<String, dynamic>> with conversation and user details
```

### 2. Search by Message Content
```dart
// Find conversations containing "project update"
final results = await conversationService.searchConversationsByMessage('project update');
// Returns conversations with matching messages highlighted
```

### 3. Comprehensive Search
```dart
// Search across both participants and messages
final results = await conversationService.searchConversations('meeting');
// Returns unified results sorted by relevance
```

### 4. Advanced Conversation Search
```dart
final results = await conversationService.advancedConversationSearch(
  participantQuery: 'John',
  messageQuery: 'urgent',
  startDate: DateTime.now().subtract(Duration(days: 7)), // Last week
  hasUnreadMessages: true, // Only unread conversations
  participantStatusFilter: ['online'], // Only with online participants
  limit: 20,
);
```

### 5. Filter Conversations by Time
```dart
// Get conversations from last week
final recentConversations = await conversationService.getConversationsByTimeframe(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
  limit: 50,
);
```

### 6. Get Unread Conversations Only
```dart
final unreadConversations = await conversationService.getUnreadConversations();
// Returns only conversations with unread messages
```

## 📱 UI Integration Examples

### 1. Search Screen with Real-time Results
```dart
class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final ConversationService _conversationService = ConversationService();
  
  List<UserModel> _userResults = [];
  List<Map<String, dynamic>> _conversationResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    
    final futures = await Future.wait([
      _userService.searchUsers(query),
      _conversationService.searchConversations(query),
    ]);
    
    setState(() {
      _userResults = futures[0];
      _conversationResults = futures[1];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search users and conversations...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userResults.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('People', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _userResults.length,
                      itemBuilder: (context, index) {
                        return UserListItem(
                          user: _userResults[index],
                          onTap: () => _startConversation(_userResults[index]),
                        );
                      },
                    ),
                  ],
                  
                  if (_conversationResults.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Conversations', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _conversationResults.length,
                      itemBuilder: (context, index) {
                        return ConversationListItem(
                          conversationData: _conversationResults[index],
                          onTap: () => _openConversation(_conversationResults[index]),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
```

### 2. Filter-based Search UI
```dart
class FilteredSearchScreen extends StatefulWidget {
  @override
  State<FilteredSearchScreen> createState() => _FilteredSearchScreenState();
}

class _FilteredSearchScreenState extends State<FilteredSearchScreen> {
  String _selectedTimeFilter = 'all';
  List<String> _selectedStatusFilters = [];
  bool _showUnreadOnly = false;

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced Search'),
      ),
      body: Column(
        children: [
          // Filters
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 12),
                  
                  // Time filter
                  DropdownButton<String>(
                    value: _selectedTimeFilter,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('All time')),
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'week', child: Text('This week')),
                      DropdownMenuItem(value: 'month', child: Text('This month')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedTimeFilter = value!);
                      _applyFilters();
                    },
                  ),
                  
                  // Status filter
                  Wrap(
                    children: ['online', 'away', 'offline'].map((status) {
                      return FilterChip(
                        label: Text(status),
                        selected: _selectedStatusFilters.contains(status),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedStatusFilters.add(status);
                            } else {
                              _selectedStatusFilters.remove(status);
                            }
                          });
                          _applyFilters();
                        },
                      );
                    }).toList(),
                  ),
                  
                  // Unread only
                  CheckboxListTile(
                    title: Text('Unread messages only'),
                    value: _showUnreadOnly,
                    onChanged: (value) {
                      setState(() => _showUnreadOnly = value!);
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _buildFilteredResults(),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    // Apply selected filters and update results
    _searchWithFilters();
  }

  Future<void> _searchWithFilters() async {
    DateTime? startDate;
    DateTime? endDate;
    
    switch (_selectedTimeFilter) {
      case 'today':
        startDate = DateTime.now().subtract(Duration(days: 1));
        break;
      case 'week':
        startDate = DateTime.now().subtract(Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime.now().subtract(Duration(days: 30));
        break;
    }
    
    final results = await _conversationService.advancedConversationSearch(
      startDate: startDate,
      endDate: endDate,
      hasUnreadMessages: _showUnreadOnly ? true : null,
      participantStatusFilter: _selectedStatusFilters.isEmpty ? null : _selectedStatusFilters,
    );
    
    // Update UI with results
    setState(() {
      // Update your results list
    });
  }
}
```

## 🔧 Performance Tips

### 1. Debounced Search
```dart
Timer? _debounceTimer;

void _onSearchChanged() {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 300), () {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query);
    }
  });
}
```

### 2. Paginated Results
```dart
Future<void> _loadMoreUsers() async {
  final moreUsers = await _userService.getAllUsers(
    limit: 20,
    lastUserId: _users.last.uid, // For pagination
  );
  
  setState(() {
    _users.addAll(moreUsers);
  });
}
```

### 3. Caching Search Results
```dart
final Map<String, List<UserModel>> _searchCache = {};

Future<List<UserModel>> _searchUsersWithCache(String query) async {
  if (_searchCache.containsKey(query)) {
    return _searchCache[query]!;
  }
  
  final results = await _userService.searchUsers(query);
  _searchCache[query] = results;
  
  return results;
}
```

## 📋 Search Result Data Structure

### User Search Results
```dart
List<UserModel> results = [
  UserModel(
    uid: 'user123',
    displayName: 'John Doe',
    phoneNumber: '+1234567890',
    onlineStatus: 'online',
    profilePhotoUrl: 'https://...',
    // ... other properties
  ),
  // ... more users
];
```

### Conversation Search Results
```dart
List<Map<String, dynamic>> results = [
  {
    'conversation': ConversationModel(...),
    'otherUser': UserModel(...),
    'unreadCount': 3,
    'matchTypes': ['participant'], // or ['message'] or ['participant', 'message']
    'matchingMessages': [MessageModel(...), ...], // if matched by message content
    'lastMatchingMessage': MessageModel(...), // most recent matching message
  },
  // ... more conversations
];
```

This comprehensive search system provides powerful functionality for finding users and conversations in your chat application!
