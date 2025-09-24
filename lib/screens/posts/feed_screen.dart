import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import 'post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMorePosts = true;
  DocumentSnapshot? _lastDocument;
  
  String _selectedCategory = 'all';
  PostType? _selectedType;
  String _searchQuery = '';
  
  final int _pageSize = 10;

  final List<String> _categories = [
    'all',
    'Electronics',
    'Clothing',
    'Books',
    'Furniture',
    'Sports',
    'Tools',
    'Toys',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMorePosts) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      _isLoading = true;
      _posts.clear();
      _lastDocument = null;
      _hasMorePosts = true;
    });

    try {
      final result = await _buildQuery()
          .limit(_pageSize)
          .get();

      if (result.docs.isNotEmpty) {
        _lastDocument = result.docs.last;
        _posts = result.docs
            .map((doc) => PostModel.fromMap(doc.data()))
            .toList();
        _hasMorePosts = result.docs.length == _pageSize;
      } else {
        _hasMorePosts = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading posts: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_lastDocument == null || !_hasMorePosts) return;

    setState(() => _isLoading = true);

    try {
      final result = await _buildQuery()
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (result.docs.isNotEmpty) {
        _lastDocument = result.docs.last;
        _posts.addAll(result.docs
            .map((doc) => PostModel.fromMap(doc.data()))
            .toList());
        _hasMorePosts = result.docs.length == _pageSize;
      } else {
        _hasMorePosts = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more posts: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('posts')
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now());

    // Filter by category
    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Filter by type
    if (_selectedType != null) {
      query = query.where('type', isEqualTo: _selectedType.toString().split('.').last);
    }

    // Search functionality (basic text match)
    // Note: Firestore doesn't support full-text search natively
    // For production, consider using Algolia or similar service
    if (_searchQuery.isNotEmpty) {
      // We'll filter on client side for now, but this is not optimal for large datasets
      // In production, use array-contains with keywords or external search service
    }

    // Sort by createdAt descending
    query = query.orderBy('createdAt', descending: true);

    return query;
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    if (_searchQuery.isEmpty) return posts;
    
    return posts.where((post) {
      final searchLower = _searchQuery.toLowerCase();
      return post.title.toLowerCase().contains(searchLower) ||
             post.brand.toLowerCase().contains(searchLower) ||
             post.description.toLowerCase().contains(searchLower);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    // Debounce search to avoid too many queries
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value) {
        _loadInitialPosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPosts = _filterPosts(_posts);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by title or brand...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                
                // Category Filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : 'all';
                            });
                            _loadInitialPosts();
                          },
                          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                
                // Type Filter
                Row(
                  children: [
                    const Text('Type: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    FilterChip(
                      label: const Text('Give'),
                      selected: _selectedType == PostType.give,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? PostType.give : null;
                        });
                        _loadInitialPosts();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Request'),
                      selected: _selectedType == PostType.request,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? PostType.request : null;
                        });
                        _loadInitialPosts();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Swap'),
                      selected: _selectedType == PostType.swap,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? PostType.swap : null;
                        });
                        _loadInitialPosts();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Posts List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialPosts,
              child: filteredPosts.isEmpty && !_isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No posts found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredPosts.length + (_hasMorePosts ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredPosts.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        final post = filteredPosts[index];
                        return PostCard(
                          post: post,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(post: post),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;
  
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (post.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  post.imageUrls.first,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 64),
                    );
                  },
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Badge and Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTypeColor(post.type),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          post.type.toString().split('.').last.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Brand and Category
                  Row(
                    children: [
                      if (post.brand.isNotEmpty) ...[
                        Icon(Icons.label, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(post.brand, style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 16),
                      ],
                      Icon(Icons.category, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(post.category, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    post.description,
                    style: TextStyle(color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Footer with user info and time
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          post.userName.isNotEmpty ? post.userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.userName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              _formatTimeAgo(post.createdAt),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Expiry indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getExpiryColor(post.expiresAt),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Expires ${_formatExpiry(post.expiresAt)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(PostType type) {
    switch (type) {
      case PostType.give:
        return Colors.green;
      case PostType.request:
        return Colors.blue;
      case PostType.swap:
        return Colors.orange;
    }
  }

  Color _getExpiryColor(DateTime expiryDate) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 1) return Colors.red;
    if (daysLeft <= 3) return Colors.orange;
    return Colors.green;
  }

  String _formatTimeAgo(DateTime dateTime) {
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

  String _formatExpiry(DateTime expiryDate) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 0) return 'today';
    if (daysLeft == 1) return 'tomorrow';
    return 'in ${daysLeft}d';
  }
}