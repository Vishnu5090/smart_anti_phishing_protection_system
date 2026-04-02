import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/phishing_detector.dart';
import '../models/url_scan_result.dart';
import 'dart:ui';

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
    _initializeDetector();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      Future.delayed(const Duration(milliseconds: 500), _scanUrl);
    }
  }

  Future<void> _initializeDetector() async {
    try {
      await _detector.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      _showSnackBar('Error initializing scanner: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _scanUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a URL');
      return;
    }

    if (!_isInitialized) {
      _showSnackBar('System is warming up...');
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _showSnackBar('Login required for scanning', isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResult = null;
    });

    try {
      final result = await _detector.analyzeUrl(url, currentUser.uid);
      setState(() {
        _scanResult = result;
        _isScanning = false;
      });
      await _databaseService.saveScanResult(currentUser.uid, result);
    } catch (e) {
      setState(() => _isScanning = false);
      _showSnackBar('Scan failed: $e', isError: true);
    }
  }

  Future<void> _openUrl() async {
    if (_scanResult == null) return;

    if (_scanResult!.securityLevel != SecurityLevel.safe) {
      final proceed = await _showWarningDialog();
      if (proceed != true) return;
    }

    try {
      String urlToOpen = _scanResult!.url;
      if (!urlToOpen.startsWith('http')) urlToOpen = 'https://$urlToOpen';
      
      final uri = Uri.parse(urlToOpen);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        final currentUser = _authService.currentUser;
        if (currentUser != null) {
          final updated = UrlScanResult(
            url: _scanResult!.url,
            securityLevel: _scanResult!.securityLevel,
            securityScore: _scanResult!.securityScore,
            threats: _scanResult!.threats,
            scannedAt: _scanResult!.scannedAt,
            wasOpened: true,
            userId: currentUser.uid,
          );
          setState(() => _scanResult = updated);
          await _databaseService.saveScanResult(currentUser.uid, updated);
        }
      }
    } catch (e) {
      _showSnackBar('Could not open browser', isError: true);
    }
  }

  Future<bool?> _showWarningDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Proceed with Caution?'),
          content: Text('This site is flagged as ${_scanResult!.securityLevel.name.toUpperCase()}. Proceeding may expose you to cyber threats.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back to Safety')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Proceed Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('URL Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInputSection(),
            const SizedBox(height: 25),
            if (_isScanning) _buildScanningLoader(),
            if (!_isScanning && _scanResult != null) _buildEnhancedResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Paste URL here...',
              prefixIcon: const Icon(Icons.shield_outlined, color: Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onSubmitted: (_) => _scanUrl(),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isScanning ? null : _scanUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text('Analyze Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningLoader() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(strokeWidth: 3),
        const SizedBox(height: 20),
        Text('Decrypting URL signatures...', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildEnhancedResultCard() {
    final color = _getSecurityColor();
    final score = _scanResult!.securityScore.toInt();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getSecurityText(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      const Text('Security Analysis', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: Icon(_getSecurityIcon(), color: Colors.white, size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildScoreCircle(score),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_scanResult!.threats.isNotEmpty) _buildThreatList(),
        const SizedBox(height: 20),
        _buildActionButton(color),
      ],
    );
  }

  Widget _buildScoreCircle(int score) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 10,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        Text('$score%', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildThreatList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk Factors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          ..._scanResult!.threats.map((t) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.report_problem, color: Colors.redAccent),
            title: Text(t, style: const TextStyle(fontSize: 14)),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButton(Color color) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: _openUrl,
        icon: const Icon(Icons.launch),
        label: Text(_scanResult!.securityLevel == SecurityLevel.safe ? 'Visit Secure Site' : 'Proceed at Own Risk'),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Color _getSecurityColor() {
    if (_scanResult == null) return Colors.grey;
    switch (_scanResult!.securityLevel) {
      case SecurityLevel.safe: return Colors.green[600]!;
      case SecurityLevel.warning: return Colors.orange[700]!;
      case SecurityLevel.danger: return Colors.red[600]!;
    }
  }

  IconData _getSecurityIcon() {
    if (_scanResult == null) return Icons.search;
    switch (_scanResult!.securityLevel) {
      case SecurityLevel.safe: return Icons.verified_user;
      case SecurityLevel.warning: return Icons.gpp_maybe;
      case SecurityLevel.danger: return Icons.gpp_bad;
    }
  }

  String _getSecurityText() => _scanResult?.securityLevel.name.toUpperCase() ?? 'NONE';
}