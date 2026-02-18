import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/url_scan_result.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save URL scan result
  Future<void> saveScanResult(String userId, UrlScanResult result) async {
    print('\n💾 SAVING SCAN RESULT...');
    print('👤 User ID: $userId');
    print('🔗 URL: ${result.url}');
    print('🛡️ Security Level: ${result.securityLevel}');
    
    try {
      // Generate unique ID for scan
      String scanId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Save scan to scan_history collection
      await _firestore
          .collection('scan_history')
          .doc(scanId)
          .set(result.toMap())
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Firestore save timeout');
              throw TimeoutException('Save timeout');
            },
          );
      
      print('✅ Scan saved to history');
      
      // Update user statistics
      await updateUserStats(userId, result.securityLevel);
      
      print('✅ Scan result saved successfully!\n');
    } catch (e) {
      print('❌ Error saving scan result: $e');
      print('⚠️ Scan not saved to history\n');
      // Don't throw - allow app to continue even if save fails
    }
  }

  // Update user statistics
  Future<void> updateUserStats(String userId, SecurityLevel level) async {
    print('📊 Updating user statistics...');
    print('👤 User ID: $userId');
    print('🛡️ Security Level: $level');
    
    try {
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        
        if (!snapshot.exists) {
          print('⚠️ User document does not exist - creating it');
          
          // Create new user document with initial stats
          transaction.set(userRef, {
            'uid': userId,
            'totalScans': 1,
            'safeSites': level == SecurityLevel.safe ? 1 : 0,
            'dangerousSites': level == SecurityLevel.danger ? 1 : 0,
          }, SetOptions(merge: true));
          
          print('✅ User document created with stats');
          return;
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        
        // Get current values with safe defaults
        int totalScans = _safeParseInt(data['totalScans'], 0);
        int safeSites = _safeParseInt(data['safeSites'], 0);
        int dangerousSites = _safeParseInt(data['dangerousSites'], 0);

        // Increment counts
        totalScans++;
        if (level == SecurityLevel.safe) {
          safeSites++;
        } else if (level == SecurityLevel.danger) {
          dangerousSites++;
        }

        print('📈 New stats: Total=$totalScans, Safe=$safeSites, Danger=$dangerousSites');

        // Update user document
        transaction.update(userRef, {
          'totalScans': totalScans,
          'safeSites': safeSites,
          'dangerousSites': dangerousSites,
        });
        
        print('✅ Statistics updated successfully');
      }).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Firestore transaction timeout');
          throw TimeoutException('Update timeout');
        },
      );
      
    } catch (e) {
      print('❌ Error updating user stats: $e');
      print('⚠️ Stats not updated\n');
      // Don't throw - allow app to continue
    }
  }

  // Get scan history for a user
  Stream<List<UrlScanResult>> getScanHistory(String userId) {
    print('📜 Setting up scan history stream for user: $userId');
    
    try {
      return _firestore
          .collection('scan_history')
          .where('userId', isEqualTo: userId)
          .orderBy('scannedAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
            print('📦 Received ${snapshot.docs.length} scan records');
            
            if (snapshot.docs.isEmpty) {
              print('ℹ️ No scan history found');
              return <UrlScanResult>[];
            }
            
            List<UrlScanResult> results = [];
            
            for (var doc in snapshot.docs) {
              try {
                Map<String, dynamic> data = doc.data();
                UrlScanResult result = UrlScanResult.fromMap(data);
                results.add(result);
              } catch (e) {
                print('⚠️ Error parsing scan result: $e');
                // Skip this document and continue
                continue;
              }
            }
            
            print('✅ Parsed ${results.length} scan results');
            return results;
          })
          .handleError((error) {
            print('❌ Error in scan history stream: $error');
            return <UrlScanResult>[];
          });
    } catch (e) {
      print('❌ Error setting up scan history stream: $e');
      // Return empty stream on error
      return Stream.value(<UrlScanResult>[]);
    }
  }

  // Get user data stream
  Stream<UserModel?> getUserStream(String userId) {
    print('👤 Setting up user data stream for: $userId');
    
    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists || snapshot.data() == null) {
              print('⚠️ User document does not exist');
              return null;
            }
            
            try {
              Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
              print('✅ User data received');
              return UserModel.fromMap(data);
            } catch (e) {
              print('❌ Error parsing user data: $e');
              return null;
            }
          })
          .handleError((error) {
            print('❌ Error in user stream: $error');
            return null;
          });
    } catch (e) {
      print('❌ Error setting up user stream: $e');
      return Stream.value(null);
    }
  }

  // Get user statistics
  Future<Map<String, int>> getUserStatistics(String userId) async {
    print('\n📊 FETCHING USER STATISTICS...');
    print('👤 User ID: $userId');
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Firestore timeout');
              throw TimeoutException('Get statistics timeout');
            },
          );
      
      if (!userDoc.exists || userDoc.data() == null) {
        print('⚠️ User document not found - returning zeros');
        return {
          'totalScans': 0,
          'safeSites': 0,
          'dangerousSites': 0,
        };
      }
      
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      
      int totalScans = _safeParseInt(data['totalScans'], 0);
      int safeSites = _safeParseInt(data['safeSites'], 0);
      int dangerousSites = _safeParseInt(data['dangerousSites'], 0);
      
      print('📈 Statistics: Total=$totalScans, Safe=$safeSites, Danger=$dangerousSites');
      print('✅ Statistics fetched successfully\n');
      
      return {
        'totalScans': totalScans,
        'safeSites': safeSites,
        'dangerousSites': dangerousSites,
      };
    } catch (e) {
      print('❌ Error getting statistics: $e');
      print('⚠️ Returning default values (all zeros)\n');
      
      // Return zeros on error
      return {
        'totalScans': 0,
        'safeSites': 0,
        'dangerousSites': 0,
      };
    }
  }

  // Get recent scans (last 10)
  Future<List<UrlScanResult>> getRecentScans(String userId) async {
    print('\n📜 FETCHING RECENT SCANS...');
    print('👤 User ID: $userId');
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('scan_history')
          .where('userId', isEqualTo: userId)
          .orderBy('scannedAt', descending: true)
          .limit(10)
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Firestore timeout');
              throw TimeoutException('Get scans timeout');
            },
          );
      
      if (snapshot.docs.isEmpty) {
        print('ℹ️ No scans found');
        print('✅ Returning empty list\n');
        return [];
      }
      
      print('📦 Found ${snapshot.docs.length} scans');
      
      List<UrlScanResult> results = [];
      
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          UrlScanResult result = UrlScanResult.fromMap(data);
          results.add(result);
        } catch (e) {
          print('⚠️ Error parsing scan: $e');
          // Skip this document and continue
          continue;
        }
      }
      
      print('✅ Parsed ${results.length} scans successfully\n');
      return results;
    } catch (e) {
      print('❌ Error getting recent scans: $e');
      print('⚠️ Returning empty list\n');
      return [];
    }
  }

  // Initialize user document if it doesn't exist
  Future<void> ensureUserDocument(String userId, String email, String displayName) async {
    print('\n🔍 CHECKING USER DOCUMENT...');
    print('👤 User ID: $userId');
    
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Firestore timeout');
              throw TimeoutException('Check user timeout');
            },
          );
      
      if (doc.exists) {
        print('✅ User document already exists\n');
        return;
      }
      
      print('⚠️ User document missing - creating it...');
      
      // Create user document with initial values
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'email': email,
        'displayName': displayName,
        'createdAt': DateTime.now().toIso8601String(),
        'totalScans': 0,
        'safeSites': 0,
        'dangerousSites': 0,
      });
      
      print('✅ User document created successfully\n');
    } catch (e) {
      print('❌ Error ensuring user document: $e');
      print('⚠️ User document may not exist\n');
      // Don't throw - allow app to continue
    }
  }

  // Safe integer parsing with default value
  int _safeParseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}