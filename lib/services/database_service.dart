import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/url_scan_result.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save scan result
  Future<void> saveScanResult(UrlScanResult result) async {
    try {
      await _firestore.collection('scan_history').add(result.toMap());
      
      // Update user statistics
      await updateUserStats(result.userId, result.securityLevel);
    } catch (e) {
      print('Error saving scan result: $e');
      throw 'Failed to save scan result';
    }
  }

  // Update user statistics
  Future<void> updateUserStats(String userId, SecurityLevel level) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        
        if (!snapshot.exists) {
          return;
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int totalScans = int.tryParse(data['totalScans']?.toString() ?? '0') ?? 0;
        int safeSites = int.tryParse(data['safeSites']?.toString() ?? '0') ?? 0;
        int dangerousSites = int.tryParse(data['dangerousSites']?.toString() ?? '0') ?? 0;

        totalScans = totalScans + 1;

        if (level == SecurityLevel.safe) {
          safeSites++;
        } else if (level == SecurityLevel.danger) {
          dangerousSites++;
        }

        transaction.update(userRef, {
          'totalScans': totalScans,
          'safeSites': safeSites,
          'dangerousSites': dangerousSites,
        });
      });
    } catch (e) {
      print('Error updating user stats: $e');
    }
  }

  // Get scan history for user
  Stream<List<UrlScanResult>> getScanHistory(String userId, {int limit = 50}) {
    return _firestore
        .collection('scan_history')
        .where('userId', isEqualTo: userId)
        .orderBy('scannedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UrlScanResult.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Get user data stream
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        try {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          return UserModel.fromMap(data);
        } catch (e) {
          print('Error parsing user data: $e');
          return null;
        }
      }
      return null;
    });
  }

  // Update URL opened status
  Future<void> markUrlAsOpened(String userId, String url) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('scan_history')
          .where('userId', isEqualTo: userId)
          .where('url', isEqualTo: url)
          .orderBy('scannedAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({'wasOpened': true});
      }
    } catch (e) {
      print('Error marking URL as opened: $e');
    }
  }

  // Get statistics
  Future<Map<String, int>> getUserStatistics(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return {
          'totalScans': int.tryParse(data['totalScans']?.toString() ?? '0') ?? 0,
          'safeSites': int.tryParse(data['safeSites']?.toString() ?? '0') ?? 0,
          'dangerousSites': int.tryParse(data['dangerousSites']?.toString() ?? '0') ?? 0,
        };
      }
      return {'totalScans': 0, 'safeSites': 0, 'dangerousSites': 0};
    } catch (e) {
      print('Error getting statistics: $e');
      return {'totalScans': 0, 'safeSites': 0, 'dangerousSites': 0};
    }
  }

  // Delete scan history
  Future<void> clearHistory(String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('scan_history')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing history: $e');
      throw 'Failed to clear history';
    }
  }
}