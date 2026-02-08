import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/phishing_dataset.dart';
import '../models/url_scan_result.dart';

class PhishingDetector {
  PhishingDataset? _dataset;
  bool _isInitialized = false;

  // Load phishing dataset
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final String response = await rootBundle.loadString('assets/phishing_dataset.json');
      final data = json.decode(response);
      _dataset = PhishingDataset.fromJson(data);
      _isInitialized = true;
    } catch (e) {
      print('Error loading dataset: $e');
      throw 'Failed to load phishing database';
    }
  }

  // Main URL scanning method
  Future<UrlScanResult> scanUrl(String url, String userId) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_dataset == null) {
      throw 'Phishing database not loaded';
    }

    List<String> threats = [];
    double score = 100.0;

    // Parse URL
    Uri? uri;
    try {
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      uri = Uri.parse(url);
    } catch (e) {
      threats.add('Invalid URL format');
      score -= 30;
    }

    if (uri != null) {
      String domain = uri.host.toLowerCase();
      String path = uri.path.toLowerCase();
      String fullUrl = url.toLowerCase();

      // Check 1: Known phishing URLs
      for (String phishingUrl in _dataset!.knownPhishingUrls) {
        if (domain.contains(phishingUrl)) {
          threats.add('Known phishing domain detected');
          score -= 60;
          break;
        }
      }

      // Check 2: Suspicious TLDs
      for (String suspiciousTld in _dataset!.suspiciousDomains) {
        if (domain.endsWith('.$suspiciousTld')) {
          threats.add('Suspicious domain extension');
          score -= 25;
          break;
        }
      }

      // Check 3: Phishing keywords in URL
      int keywordMatches = 0;
      for (String keyword in _dataset!.phishingKeywords) {
        if (fullUrl.contains(keyword)) {
          keywordMatches++;
        }
      }
      if (keywordMatches > 0) {
        threats.add('Contains $keywordMatches phishing keyword(s)');
        score -= (keywordMatches * 10);
      }

      // Check 4: IP address as domain
      if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(domain)) {
        threats.add('IP address used instead of domain');
        score -= 30;
      }

      // Check 5: Excessive subdomains
      List<String> parts = domain.split('.');
      if (parts.length > 4) {
        threats.add('Unusual number of subdomains');
        score -= 20;
      }

      // Check 6: Missing HTTPS
      if (uri.scheme == 'http') {
        threats.add('Not using secure HTTPS protocol');
        score -= 15;
      }

      // Check 7: URL length
      if (url.length > 100) {
        threats.add('Unusually long URL');
        score -= 10;
      }

      // Check 8: Special characters
      if (domain.contains('@') || domain.contains('-') && domain.split('-').length > 3) {
        threats.add('Suspicious characters in domain');
        score -= 15;
      }

      // Check 9: Safe domains (whitelist)
      bool isSafeDomain = false;
      for (String safeDomain in _dataset!.safeDomains) {
        if (domain.endsWith(safeDomain)) {
          isSafeDomain = true;
          score = 100;
          threats.clear();
          break;
        }
      }

      // Check 10: Homograph attack (similar looking characters)
      if (domain.contains('0') || domain.contains('1') || 
          domain.contains('rn') || domain.contains('vv')) {
        if (!isSafeDomain) {
          threats.add('Possible character spoofing detected');
          score -= 20;
        }
      }
    }

    // Normalize score
    if (score < 0) score = 0;
    if (score > 100) score = 100;

    // Determine security level
    SecurityLevel level;
    if (score >= 90) {
      level = SecurityLevel.safe;
    } else if (score >= 50) {
      level = SecurityLevel.warning;
    } else {
      level = SecurityLevel.danger;
    }

    return UrlScanResult(
      url: url,
      securityLevel: level,
      securityScore: score,
      threats: threats,
      scannedAt: DateTime.now(),
      userId: userId,
    );
  }

  // Quick check without full scan
  Future<bool> isUrlSafe(String url) async {
    final result = await scanUrl(url, '');
    return result.securityLevel == SecurityLevel.safe;
  }
}