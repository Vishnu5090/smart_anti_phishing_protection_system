import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/phishing_detector.dart';
import '../models/url_scan_result.dart';

class UrlCheckScreen extends StatefulWidget {
  final String? initialUrl;

  const UrlCheckScreen({Key? key, this.initialUrl}) : super(key: key);

  @override
  State<UrlCheckScreen> createState() => _UrlCheckScreenState();
}

class _UrlCheckScreenState extends State<UrlCheckScreen> {
  final TextEditingController _urlController = TextEditingController();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final PhishingDetector _detector = PhishingDetector();

  UrlScanResult? _scanResult;
  bool _isScanning = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    print('\n🔍 URL CHECK SCREEN INITIALIZED');
    _initializeDetector();
    
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      Future.delayed(Duration(milliseconds: 500), () {
        _scanUrl();
      });
    }
  }

  Future<void> _initializeDetector() async {
    print('🔧 Initializing phishing detector...');
    try {
      await _detector.initialize();
      setState(() {
        _isInitialized = true;
      });
      print('✅ Phishing detector ready\n');
    } catch (e) {
      print('❌ Error initializing detector: $e\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing scanner: $e')),
        );
      }
    }
  }

  Future<void> _scanUrl() async {
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL')),
      );
      return;
    }

    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanner is still initializing...')),
      );
      return;
    }

    // Check if user is logged in
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to scan URLs')),
      );
      return;
    }

    print('\n🔍 SCANNING URL...');
    print('🔗 URL: ${_urlController.text.trim()}');
    print('👤 User ID: ${currentUser.uid}'); // Debug log

    setState(() {
      _isScanning = true;
      _scanResult = null;
    });

    try {
      final url = _urlController.text.trim();
      
      // FIXED: Pass userId to analyzeUrl
      final result = await _detector.analyzeUrl(url, currentUser.uid);

      print('✅ SCAN COMPLETE!');
      print('🛡️ Security Level: ${result.securityLevel}');
      print('📊 Security Score: ${result.securityScore}');
      print('👤 Result User ID: ${result.userId}'); // Verify userId is set
      print('⚠️ Threats: ${result.threats.length}\n');

      setState(() {
        _scanResult = result;
        _isScanning = false;
      });

      // Save scan result to database
      print('💾 Saving scan to database...');
      print('👤 Saving for user: ${currentUser.uid}');
      await _databaseService.saveScanResult(currentUser.uid, result);
      print('✅ Scan saved to database\n');
      
    } catch (e) {
      print('❌ ERROR SCANNING URL: $e\n');
      
      setState(() {
        _isScanning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning URL: $e')),
        );
      }
    }
  }

  Future<void> _openUrl() async {
    if (_scanResult == null) {
      print('⚠️ No scan result to open');
      return;
    }

    print('\n🌐 ATTEMPTING TO OPEN URL...');
    print('🔗 URL: ${_scanResult!.url}');
    print('🛡️ Security Level: ${_scanResult!.securityLevel}');

    // Show warning for dangerous/warning URLs
    if (_scanResult!.securityLevel != SecurityLevel.safe) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning,
                color: _scanResult!.securityLevel == SecurityLevel.danger
                    ? Colors.red
                    : Colors.orange,
              ),
              const SizedBox(width: 12),
              const Text('Security Warning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This URL has been flagged as ${_scanResult!.securityLevel == SecurityLevel.danger ? "DANGEROUS" : "SUSPICIOUS"}.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_scanResult!.threats.isNotEmpty) ...[
                const Text(
                  'Detected threats:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._scanResult!.threats.map((threat) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(threat)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              const Text('Are you sure you want to proceed?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Anyway'),
            ),
          ],
        ),
      );

      if (shouldOpen != true) {
        print('❌ User cancelled opening URL\n');
        return;
      }
    }

    // Open the URL
    try {
      String urlToOpen = _scanResult!.url;
      
      // Ensure URL has protocol
      if (!urlToOpen.startsWith('http://') && !urlToOpen.startsWith('https://')) {
        urlToOpen = 'https://$urlToOpen';
      }
      
      print('🔗 Final URL to open: $urlToOpen');
      
      final uri = Uri.parse(urlToOpen);
      
      // Try to launch
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched) {
        print('✅ URL opened successfully in browser\n');

        // Update scan result to mark as opened
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          final updatedResult = UrlScanResult(
            url: _scanResult!.url,
            securityLevel: _scanResult!.securityLevel,
            securityScore: _scanResult!.securityScore,
            threats: _scanResult!.threats,
            scannedAt: _scanResult!.scannedAt,
            wasOpened: true,
            userId: currentUser.uid, // Ensure userId is set
          );
          
          setState(() {
            _scanResult = updatedResult;
          });

          // Save updated result
          await _databaseService.saveScanResult(currentUser.uid, updatedResult);
          print('✅ Updated scan result saved\n');
        }
      } else {
        print('❌ Failed to launch URL\n');
        throw 'Could not launch URL';
      }
      
    } catch (e) {
      print('❌ ERROR OPENING URL: $e\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open this URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getSecurityColor() {
    if (_scanResult == null) return Colors.grey;
    switch (_scanResult!.securityLevel) {
      case SecurityLevel.safe:
        return Colors.green;
      case SecurityLevel.warning:
        return Colors.orange;
      case SecurityLevel.danger:
        return Colors.red;
    }
  }

  IconData _getSecurityIcon() {
    if (_scanResult == null) return Icons.search;
    switch (_scanResult!.securityLevel) {
      case SecurityLevel.safe:
        return Icons.check_circle;
      case SecurityLevel.warning:
        return Icons.warning;
      case SecurityLevel.danger:
        return Icons.dangerous;
    }
  }

  String _getSecurityText() {
    if (_scanResult == null) return 'Not Scanned';
    switch (_scanResult!.securityLevel) {
      case SecurityLevel.safe:
        return 'SAFE';
      case SecurityLevel.warning:
        return 'WARNING';
      case SecurityLevel.danger:
        return 'DANGER';
    }
  }

  Widget _buildResultCard() {
    if (_scanResult == null) return const SizedBox.shrink();

    final color = _getSecurityColor();
    final icon = _getSecurityIcon();
    final text = _getSecurityText();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color, width: 3),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // Security Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: color,
              ),
            ),
            const SizedBox(height: 24),

            // Security Status
            Text(
              text,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),

            // Security Score
            Text(
              'Security Score: ${_scanResult!.securityScore.toInt()}',
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Score Meter
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _scanResult!.securityScore / 100,
                minHeight: 20,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 24),

            // Threats List
            if (_scanResult!.threats.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detected Threats:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...(_scanResult!.threats.map((threat) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error, size: 20, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            threat,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))),
              const SizedBox(height: 16),
            ],

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openUrl,
                icon: const Icon(Icons.open_in_browser),
                label: Text(
                  _scanResult!.securityLevel == SecurityLevel.safe
                      ? 'Open URL'
                      : 'Open Anyway',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan URL'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter a URL to check for phishing threats',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // URL Input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Enter URL',
                hintText: 'https://example.com',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _urlController.clear();
                            _scanResult = null;
                          });
                        },
                      )
                    : null,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _scanUrl(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Scan Button
            ElevatedButton.icon(
              onPressed: _isScanning || !_isInitialized ? null : _scanUrl,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isScanning ? 'Scanning...' : 'Scan URL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),

            // Result Card
            _buildResultCard(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}