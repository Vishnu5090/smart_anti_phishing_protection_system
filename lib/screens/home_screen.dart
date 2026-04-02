import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'history_screen.dart';
import 'url_check_screen.dart';
import 'support_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  int _currentIndex = 0; // Tracks the active tab

  User? _currentUser;
  UserModel? _userModel;
  Map<String, int> _stats = {
    'totalScans': 0,
    'safeSites': 0,
    'dangerousSites': 0
  };

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = _authService.currentUser;

      if (_currentUser == null) {
        setState(() {
          _errorMessage = 'No user logged in';
          _isLoading = false;
        });
        return;
      }

      await _databaseService.ensureUserDocument(
        _currentUser!.uid,
        _currentUser!.email ?? '',
        _currentUser!.displayName ?? _currentUser!.email?.split('@')[0] ?? 'User',
      );

      _userModel = await _authService.getUserData(_currentUser!.uid);
      _stats = await _databaseService.getUserStatistics(_currentUser!.uid);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading data';
        });
      }
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
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of screens for the navigation bar
    final List<Widget> _pages = [
      _buildHomeContent(),     // Index 0
      const UrlCheckScreen(),  // Index 1
      const HistoryScreen(),   // Index 2
      const SupportScreen(), // Index 3 Placeholder
    ];

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Smart AntiPhishing', 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _signOut),
        ],
      ),
      // Displays the body based on the current selection
      body: _pages[_currentIndex],
      
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 0),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 0) _loadUserData(); // Refresh stats when returning home
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue.shade700,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Scan URL'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.contact_support_rounded), label: 'Support'),
          ],
        ),
      ),
    );
  }

  // --- HOME CONTENT VIEW ---
  Widget _buildHomeContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadUserData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final totalScans = _stats['totalScans'] ?? 0;
    final safeSites = _stats['safeSites'] ?? 0;
    final dangerousSites = _stats['dangerousSites'] ?? 0;
    final warningSites = totalScans - safeSites - dangerousSites;

    String displayName = _userModel?.displayName ?? "User";
    if (displayName.trim().isEmpty) displayName = "User";
    String initial = displayName[0].toUpperCase();

    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildWelcomeCard(initial, displayName),
          const SizedBox(height: 32),
          const Text('Security Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildEnhancedStatsGrid(totalScans, safeSites, dangerousSites, warningSites),
          const SizedBox(height: 32),
          if (totalScans > 0) 
            _buildEnhancedChartSection(safeSites, warningSites, dangerousSites, totalScans) 
          else 
            _buildEmptyState(),
          const SizedBox(height: 32),
          _buildActionButtons(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- UI HELPERS (KEEPING YOUR ORIGINAL DESIGN) ---

  Widget _buildWelcomeCard(String initial, String displayName) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).primaryColor, Colors.blueAccent],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.security, size: 150, color: Colors.white.withOpacity(0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        radius: 18,
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      const Text('System Protected', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Hello, ${displayName.split(' ')[0]}!',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(_userModel?.email ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                  const SizedBox(height: 16),
                  _buildStatusBadge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text('Account Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatsGrid(int total, int safe, int danger, int warn) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Total Scans', total.toString(), Icons.radar, Colors.blue.shade700),
        _buildStatCard('Safe Sites', safe.toString(), Icons.check_circle_rounded, Colors.green.shade600),
        _buildStatCard('Malicious', danger.toString(), Icons.gpp_bad_rounded, Colors.red.shade600),
        _buildStatCard('Warnings', warn.toString(), Icons.warning_rounded, Colors.amber.shade700),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEnhancedChartSection(int safe, int warn, int danger, int total) {
    double safetyScore = total > 0 ? (safe / total) * 100 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Threat Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 140, width: 140,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 45,
                        sections: [
                          PieChartSectionData(value: safe.toDouble(), color: Colors.green, radius: 12, showTitle: false),
                          PieChartSectionData(value: warn.toDouble(), color: Colors.orange, radius: 12, showTitle: false),
                          PieChartSectionData(value: danger.toDouble(), color: Colors.red, radius: 12, showTitle: false),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${safetyScore.toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                          const Text('Safe', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildLegendItem('Safe', Colors.green, safe, total),
                    const SizedBox(height: 12),
                    _buildLegendItem('Warning', Colors.orange, warn, total),
                    const SizedBox(height: 12),
                    _buildLegendItem('Danger', Colors.red, danger, total),
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count, int total) {
    double percent = total > 0 ? (count / total) * 100 : 0;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              LinearProgressIndicator(
                value: percent / 100,
                backgroundColor: color.withOpacity(0.1),
                color: color,
                minHeight: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${percent.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No Analytics Yet', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Run a scan to see your safety score.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _currentIndex = 1); // Switch to Scan Tab
              },
              icon: const Icon(Icons.search_rounded),
              label: const Text('Scan URL', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() => _currentIndex = 2); // Switch to History Tab
            },
            icon: const Icon(Icons.history_rounded),
            label: const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}