class PhishingDataset {
  final List<String> phishingKeywords;
  final List<String> suspiciousDomains;
  final List<String> knownPhishingUrls;
  final List<String> safeDomains;
  final Map<String, String> urlPatterns;

  PhishingDataset({
    required this.phishingKeywords,
    required this.suspiciousDomains,
    required this.knownPhishingUrls,
    required this.safeDomains,
    required this.urlPatterns,
  });

  factory PhishingDataset.fromJson(Map<String, dynamic> json) {
    return PhishingDataset(
      phishingKeywords: List<String>.from(json['phishing_keywords'] ?? []),
      suspiciousDomains: List<String>.from(json['suspicious_domains'] ?? []),
      knownPhishingUrls: List<String>.from(json['known_phishing_urls'] ?? []),
      safeDomains: List<String>.from(json['safe_domains'] ?? []),
      urlPatterns: Map<String, String>.from(json['url_patterns'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phishing_keywords': phishingKeywords,
      'suspicious_domains': suspiciousDomains,
      'known_phishing_urls': knownPhishingUrls,
      'safe_domains': safeDomains,
      'url_patterns': urlPatterns,
    };
  }
}