import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/url_scan_result.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    print('\n📜 HISTORY SCREEN INITIALIZED');
  }

  Color _getSecurityColor(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.safe:
        return Colors.green;
      case SecurityLevel.warning:
        return Colors.orange;
      case SecurityLevel.danger:
        return Colors.red;
    }
  }

  IconData _getSecurityIcon(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.safe:
        return Icons.check_circle;
      case SecurityLevel.warning:
        return Icons.warning;
      case SecurityLevel.danger:
        return Icons.dangerous;
    }
  }

  String _getSecurityText(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.safe:
        return 'SAFE';
      case SecurityLevel.warning:
        return 'WARNING';
      case SecurityLevel.danger:
        return 'DANGER';
    }
  }

  Widget _buildHistoryItem(UrlScanResult result) {
    final color = _getSecurityColor(result.securityLevel);
    final icon = _getSecurityIcon(result.securityLevel);
    final text = _getSecurityText(result.securityLevel);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailsDialog(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Security Badge & Score
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Score: ${result.securityScore.toInt()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // URL
              Text(
                result.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              // Timestamp
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(result.scannedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              // Threats
              if (result.threats.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.threats.take(2).map((threat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        threat,
                        style: TextStyle(fontSize: 10, color: Colors.red[700]),
                      ),
                    );
                  }).toList(),
                ),
                if (result.threats.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${result.threats.length - 2} more',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(UrlScanResult result) {
    final color = _getSecurityColor(result.securityLevel);
    final icon = _getSecurityIcon(result.securityLevel);
    final text = _getSecurityText(result.securityLevel);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            const Text('Scan Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Security Level
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 40, color: color),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: ${result.securityScore.toInt()}',
                      style: TextStyle(color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // URL
              const Text('URL:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(result.url),
              const SizedBox(height: 16),

              // Timestamp
              const Text('Scanned:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(result.scannedAt)),
              const SizedBox(height: 16),

              // Status
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                result.wasOpened ? 'URL was opened' : 'URL was blocked',
                style: TextStyle(
                  color: result.wasOpened ? Colors.orange : Colors.green,
                ),
              ),

              // Threats
              if (result.threats.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Threats:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.threats.map((threat) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error, size: 16, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(child: Text(threat)),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan History')),
        body: const Center(child: Text('No user logged in')),
      );
    }

    print('👤 Building history for user: ${currentUser.uid}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('scan_history')
            .where('userId', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          print('\n📦 HISTORY STREAM STATE: ${snapshot.connectionState}');
          
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading scan history...'),
                ],
              ),
            );
          }

          // Error
          if (snapshot.hasError) {
            print('❌ HISTORY ERROR: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Error Loading History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // No data
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('ℹ️ NO HISTORY FOUND');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No Scan History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start scanning URLs to build your history',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          // Parse documents
          final docs = snapshot.data!.docs;
          print('✅ FOUND ${docs.length} SCANS');

          // Sort by timestamp (client-side to avoid index requirement)
          final sortedDocs = docs.toList();
          sortedDocs.sort((a, b) {
            try {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['scannedAt'] as Timestamp?;
              final bTime = bData['scannedAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime); // Descending order
            } catch (e) {
              return 0;
            }
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              try {
                final data = sortedDocs[index].data() as Map<String, dynamic>;
                final result = UrlScanResult.fromMap(data);
                
                return _buildHistoryItem(result);
              } catch (e) {
                print('⚠️ ERROR PARSING SCAN: $e');
                return const SizedBox.shrink();
              }
            },
          );
        },
      ),
    );
  }
}