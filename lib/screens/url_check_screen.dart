import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/phishing_detector.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../models/url_scan_result.dart';
import 'dart:math' as math;

class UrlCheckScreen extends StatefulWidget {
  final String? initialUrl;

  const UrlCheckScreen({Key? key, this.initialUrl}) : super(key: key);

  @override
  State<UrlCheckScreen> createState() => _UrlCheckScreenState();
}

class _UrlCheckScreenState extends State<UrlCheckScreen> with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final PhishingDetector _detector = PhishingDetector();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  
  UrlScanResult? _scanResult;
  bool _isScanning = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _scanUrl();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _scanUrl() async {
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResult = null;
    });

    try {
      String userId = _authService.currentUser?.uid ?? '';
      UrlScanResult result = await _detector.scanUrl(_urlController.text.trim(), userId);
      
      if (userId.isNotEmpty) {
        await _databaseService.saveScanResult(result);
      }

      setState(() {
        _scanResult = result;
      });

      _animationController.forward(from: 0.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _openUrl() async {
    if (_scanResult == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open URL'),
        content: Text(
          _scanResult!.securityLevel == SecurityLevel.danger
              ? 'This URL is dangerous! Are you sure you want to open it?'
              : 'Do you want to open this URL?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _scanResult!.securityLevel == SecurityLevel.danger
                  ? Colors.red
                  : Colors.blue,
            ),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final Uri uri = Uri.parse(_scanResult!.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          String userId = _authService.currentUser?.uid ?? '';
          if (userId.isNotEmpty) {
            await _databaseService.markUrlAsOpened(userId, _scanResult!.url);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open URL: $e')),
          );
        }
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
    if (_scanResult == null) return Icons.security;
    
    switch (_scanResult!.securityLevel) {
      case SecurityLevel.safe:
        return Icons.check_circle;
      case SecurityLevel.warning:
        return Icons.warning;
      case SecurityLevel.danger:
        return Icons.dangerous;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Scanner'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Input Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter URL to Scan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade700,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) => setState(() {}),
                          onSubmitted: (_) => _scanUrl(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? null : _scanUrl,
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
                            label: Text(
                              _isScanning ? 'Scanning...' : 'Scan URL',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Results Section
                if (_scanResult != null) ...[
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getSecurityColor().withOpacity(0.1),
                              _getSecurityColor().withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Security Meter
                              _buildSecurityMeter(),
                              const SizedBox(height: 24),
                              
                              // Security Level
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _getSecurityColor(),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getSecurityIcon(),
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _scanResult!.securityLevelText.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Description
                              Text(
                                _scanResult!.securityDescription,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Threats
                              if (_scanResult!.threats.isNotEmpty) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Detected Threats:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._scanResult!.threats.map((threat) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.warning_amber,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              threat,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 16),
                              ],
                              
                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _scanResult = null;
                                          _urlController.clear();
                                        });
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Scan Another'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: BorderSide(color: Colors.blue.shade700),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _openUrl,
                                      icon: const Icon(Icons.open_in_browser),
                                      label: const Text('Open URL'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _getSecurityColor(),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Info Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Our AI-powered system analyzes URLs for:\n'
                          '• Known phishing patterns\n'
                          '• Suspicious domain names\n'
                          '• Security protocols\n'
                          '• URL structure anomalies',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityMeter() {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: SecurityMeterPainter(
          score: _scanResult!.securityScore,
          color: _getSecurityColor(),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_scanResult!.securityScore.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _getSecurityColor(),
                ),
              ),
              Text(
                'Security Score',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SecurityMeterPainter extends CustomPainter {
  final double score;
  final Color color;

  SecurityMeterPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}