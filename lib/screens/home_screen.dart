import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'history_screen.dart';
import 'url_check_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  
  User? _currentUser;
  UserModel? _userModel;
  Map<String, int> _stats = {'totalScans': 0, 'safeSites': 0, 'dangerousSites': 0};
  
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('\n🏠 HOME SCREEN INITIALIZED');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    print('\n📊 LOADING USER DATA...');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = _authService.currentUser;
      
      if (_currentUser == null) {
        print('❌ No current user found');
        setState(() {
          _errorMessage = 'No user logged in';
          _isLoading = false;
        });
        return;
      }

      print('✅ Current user: ${_currentUser!.uid}');
      print('📧 Email: ${_currentUser!.email}');

      // Ensure user document exists
      await _databaseService.ensureUserDocument(
        _currentUser!.uid,
        _currentUser!.email ?? '',
        _currentUser!.displayName ?? _currentUser!.email?.split('@')[0] ?? 'User',
      );

      // Get user data
      _userModel = await _authService.getUserData(_currentUser!.uid);
      
      if (_userModel == null) {
        print('⚠️ No user model found - using fallback');
        _userModel = UserModel(
          uid: _currentUser!.uid,
          email: _currentUser!.email ?? '',
          displayName: _currentUser!.displayName ?? _currentUser!.email?.split('@')[0] ?? 'User',
          createdAt: DateTime.now(),
          totalScans: 0,
          safeSites: 0,
          dangerousSites: 0,
        );
      }

      // Get statistics
      print('📊 Fetching statistics...');
      _stats = await _databaseService.getUserStatistics(_currentUser!.uid);
      print('✅ Statistics loaded: $_stats');

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      print('✅ HOME SCREEN DATA LOADED SUCCESSFULLY\n');
      
    } catch (e) {
      print('❌ ERROR LOADING USER DATA: $e\n');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data';
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('❌ Error signing out: $e');
    }
  }

  void _navigateToUrlCheck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const UrlCheckScreen()),
    );
    // Refresh stats when returning
    _loadUserData();
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart AntiPhishing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart AntiPhishing')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final totalScans = _stats['totalScans'] ?? 0;
    final safeSites = _stats['safeSites'] ?? 0;
    final dangerousSites = _stats['dangerousSites'] ?? 0;
    final warningSites = totalScans - safeSites - dangerousSites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart AntiPhishing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Card
            Card(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.shade300],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userModel?.displayName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _userModel?.email ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Statistics Title
            const Text(
              'Your Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Statistics Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  'Total Scans',
                  totalScans.toString(),
                  Icons.search,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Safe Sites',
                  safeSites.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  'Dangerous',
                  dangerousSites.toString(),
                  Icons.warning,
                  Colors.red,
                ),
                _buildStatCard(
                  'Warning',
                  warningSites.toString(),
                  Icons.info,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pie Chart
            if (totalScans > 0) ...[
              const Text(
                'Scan Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (safeSites > 0)
                            PieChartSectionData(
                              value: safeSites.toDouble(),
                              title: safeSites.toString(),
                              color: Colors.green,
                              radius: 50,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (warningSites > 0)
                            PieChartSectionData(
                              value: warningSites.toDouble(),
                              title: warningSites.toString(),
                              color: Colors.orange,
                              radius: 50,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (dangerousSites > 0)
                            PieChartSectionData(
                              value: dangerousSites.toDouble(),
                              title: dangerousSites.toString(),
                              color: Colors.red,
                              radius: 50,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No scans yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start scanning URLs to see statistics',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToUrlCheck,
                    icon: const Icon(Icons.search),
                    label: const Text('Scan URL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}