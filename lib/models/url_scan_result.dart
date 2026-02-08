import 'package:cloud_firestore/cloud_firestore.dart';

enum SecurityLevel {
  safe,
  warning,
  danger,
}

class UrlScanResult {
  final String url;
  final SecurityLevel securityLevel;
  final double securityScore;
  final List<String> threats;
  final DateTime scannedAt;
  final String userId;
  final bool wasOpened;

  UrlScanResult({
    required this.url,
    required this.securityLevel,
    required this.securityScore,
    required this.threats,
    required this.scannedAt,
    required this.userId,
    this.wasOpened = false,
  });

  factory UrlScanResult.fromMap(Map<String, dynamic> map) {
    return UrlScanResult(
      url: map['url'] ?? '',
      securityLevel: SecurityLevel.values.firstWhere(
        (e) => e.toString() == 'SecurityLevel.${map['securityLevel']}',
        orElse: () => SecurityLevel.warning,
      ),
      securityScore: (map['securityScore'] ?? 0).toDouble(),
      threats: List<String>.from(map['threats'] ?? []),
      scannedAt: (map['scannedAt'] as Timestamp).toDate(),
      userId: map['userId'] ?? '',
      wasOpened: map['wasOpened'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'securityLevel': securityLevel.toString().split('.').last,
      'securityScore': securityScore,
      'threats': threats,
      'scannedAt': Timestamp.fromDate(scannedAt),
      'userId': userId,
      'wasOpened': wasOpened,
    };
  }

  String get securityLevelText {
    switch (securityLevel) {
      case SecurityLevel.safe:
        return 'Safe';
      case SecurityLevel.warning:
        return 'Warning';
      case SecurityLevel.danger:
        return 'Danger';
    }
  }

  String get securityDescription {
    switch (securityLevel) {
      case SecurityLevel.safe:
        return 'This URL appears to be safe';
      case SecurityLevel.warning:
        return 'This URL has suspicious characteristics';
      case SecurityLevel.danger:
        return 'This URL is likely a phishing attempt';
    }
  }
}