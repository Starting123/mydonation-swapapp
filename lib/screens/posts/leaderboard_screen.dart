import 'package:flutter/material.dart';
import '../../models/reputation_model.dart';
import '../../services/reputation_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final ReputationService _reputationService = ReputationService();
  
  List<UserReputationModel> _leaderboard = [];
  bool _isLoading = true;
  String _selectedTab = 'all'; // all, donors, helpers
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    
    try {
      final leaderboard = await _reputationService.getLeaderboard(limit: 100);
      setState(() {
        _leaderboard = leaderboard;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leaderboard: $e')),
        );
      }
    }
  }

  List<UserReputationModel> get _filteredLeaderboard {
    switch (_selectedTab) {
      case 'donors':
        return _leaderboard.where((user) => user.successfulDonations > 0).toList();
      case 'helpers':
        return _leaderboard.where((user) => user.positiveFeedbacks >= 5).toList();
      default:
        return _leaderboard;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _selectedTab = ['all', 'donors', 'helpers'][index];
            });
          },
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(
              icon: Icon(Icons.emoji_events),
              text: 'All Users',
            ),
            Tab(
              icon: Icon(Icons.volunteer_activism),
              text: 'Top Donors',
            ),
            Tab(
              icon: Icon(Icons.favorite),
              text: 'Top Helpers',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: _filteredLeaderboard.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.leaderboard, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            'Start contributing to appear on the leaderboard!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Top 3 podium
                        if (_filteredLeaderboard.length >= 3)
                          _buildPodium(_filteredLeaderboard.take(3).toList()),
                        
                        // Stats summary
                        _buildStatsCard(),
                        
                        // Rest of the leaderboard
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredLeaderboard.length,
                            itemBuilder: (context, index) {
                              final user = _filteredLeaderboard[index];
                              return _buildLeaderboardItem(user, index + 1);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildPodium(List<UserReputationModel> topThree) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (topThree.length > 1) _buildPodiumItem(topThree[1], 2, 120),
          // 1st place
          _buildPodiumItem(topThree[0], 1, 150),
          // 3rd place
          if (topThree.length > 2) _buildPodiumItem(topThree[2], 3, 100),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(UserReputationModel user, int position, double height) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // User avatar
        Stack(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colors[position - 1],
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  user.userName.isNotEmpty ? user.userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors[position - 1],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors[position - 1],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$position',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // User name
        Text(
          user.userName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Points
        Text(
          '${user.totalPoints} pts',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Podium base
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: colors[position - 1].withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: colors[position - 1], width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ReputationService.getLevelIcon(user.level),
                color: colors[position - 1],
                size: 24,
              ),
              Text(
                user.level,
                style: TextStyle(
                  color: colors[position - 1],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    if (_leaderboard.isEmpty) return const SizedBox.shrink();
    
    final totalUsers = _leaderboard.length;
    final totalDonations = _leaderboard.fold<int>(0, (sum, user) => sum + user.successfulDonations);
    final totalFeedbacks = _leaderboard.fold<int>(0, (sum, user) => sum + user.positiveFeedbacks);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.people,
            label: 'Active Users',
            value: totalUsers.toString(),
            color: Colors.blue,
          ),
          _buildStatItem(
            icon: Icons.volunteer_activism,
            label: 'Total Donations',
            value: totalDonations.toString(),
            color: Colors.green,
          ),
          _buildStatItem(
            icon: Icons.thumb_up,
            label: 'Positive Feedbacks',
            value: totalFeedbacks.toString(),
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem(UserReputationModel user, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: rank <= 3 ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: rank <= 3 ? ReputationService.getLevelColor(user.level) : Colors.transparent,
          width: rank <= 3 ? 2 : 0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rank
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank <= 3 
                    ? ReputationService.getLevelColor(user.level)
                    : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rank <= 3 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: ReputationService.getLevelColor(user.level),
              child: Text(
                user.userName.isNotEmpty ? user.userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ReputationService.getLevelColor(user.level),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ReputationService.getLevelIcon(user.level),
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    user.level,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${user.totalPoints} points',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildMiniStat(
                  icon: Icons.volunteer_activism,
                  value: user.successfulDonations,
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _buildMiniStat(
                  icon: Icons.thumb_up,
                  value: user.positiveFeedbacks,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildMiniStat(
                  icon: Icons.check_circle,
                  value: user.completedPosts,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
        trailing: rank <= 3
            ? Icon(
                Icons.emoji_events,
                color: ReputationService.getLevelColor(user.level),
                size: 28,
              )
            : null,
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required int value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}