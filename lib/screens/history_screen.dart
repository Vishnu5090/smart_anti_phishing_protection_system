import 'package:flutter/material.dart';
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

  // Helper for consistent colors across the app
  Color _getSecurityColor(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.safe: return Colors.green.shade600;
      case SecurityLevel.warning: return Colors.orange.shade700;
      case SecurityLevel.danger: return Colors.red.shade600;
    }
  }

  IconData _getSecurityIcon(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.safe: return Icons.check_circle_rounded;
      case SecurityLevel.warning: return Icons.warning_rounded;
      case SecurityLevel.danger: return Icons.gpp_bad_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scan History', 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      body: currentUser == null
          ? const Center(child: Text('Please log in to view history'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('scan_history')
                  .where('userId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs.toList();
                // Sort client-side to keep the UX snappy without complex Firebase indices
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['scannedAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['scannedAt'] as Timestamp?;
                  return (bTime ?? Timestamp.now()).compareTo(aTime ?? Timestamp.now());
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: docs.length + 1, // +1 for the header
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildHistoryHeader(docs.length);
                    
                    try {
                      final data = docs[index - 1].data() as Map<String, dynamic>;
                      final result = UrlScanResult.fromMap(data);
                      return _buildHistoryCard(result);
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildHistoryHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activities',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            'You have performed $count scans',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(UrlScanResult result) {
    final color = _getSecurityColor(result.securityLevel);
    final icon = _getSecurityIcon(result.securityLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => _showDetailsBottomSheet(result),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Badge
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(result.scannedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // Score indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.securityScore.toInt()}%',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color),
                  ),
                  const Text('SCORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsBottomSheet(UrlScanResult result) {
    final color = _getSecurityColor(result.securityLevel);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(_getSecurityIcon(result.securityLevel), color: color, size: 32),
                const SizedBox(width: 12),
                const Text('Scan Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow('Analyzed URL', result.url, isSelectable: true),
            _buildInfoRow('Security Level', result.securityLevel.name.toUpperCase(), valueColor: color),
            _buildInfoRow('Safety Score', '${result.securityScore.toInt()}%'),
            _buildInfoRow('Detection Time', DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(result.scannedAt)),
            
            if (result.threats.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Threats Detected', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.threats.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade100)),
                  child: Text(t, style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSelectable = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          isSelectable 
            ? SelectableText(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87))
            : Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          const Text('No Scan History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Your URL scan history will appear here.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}