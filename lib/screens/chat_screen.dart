import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String hackerName;
  final String hackerId;

  const ChatScreen({
    Key? key,
    required this.hackerName,
    required this.hackerId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _debugChatSetup();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Debug function to print chat setup info
  void _debugChatSetup() {
    print('\n' + '=' * 60);
    print('🔐 CHAT SCREEN INITIALIZED');
    print('=' * 60);
    print('👤 Current User UID: ${_auth.currentUser?.uid}');
    print('🎯 Hacker Name: ${widget.hackerName}');
    print('🆔 Hacker ID: ${widget.hackerId}');
    print('💬 Chat Room ID: $_chatRoomId');
    print('=' * 60 + '\n');
  }

  // Generate chat room ID (sorted alphabetically for consistency)
  String get _chatRoomId {
    final String currentUid = _auth.currentUser!.uid.trim();
    final String partnerId = widget.hackerId.trim();

    // Sort IDs alphabetically to ensure same room ID for both users
    List<String> ids = [currentUid, partnerId];
    ids.sort();

    return ids.join("_");
  }

  // Send message with proper error handling
  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    
    if (text.isEmpty) {
      return;
    }

    if (_isSending) {
      return; // Prevent duplicate sends
    }

    // Clear input immediately for better UX
    _messageController.clear();
    
    setState(() {
      _isSending = true;
    });

    print('\n📤 SENDING MESSAGE...');
    print('💬 Chat Room: $_chatRoomId');
    print('👤 Sender: ${_auth.currentUser!.uid}');
    print('📝 Text: $text');

    try {
      final message = MessageModel(
        senderId: _auth.currentUser!.uid,
        text: text,
        timestamp: Timestamp.now(),
      );

      // Send to Firestore
      await _firestore
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add(message.toMap())
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw 'Message send timeout';
            },
          );

      print('✅ Message sent successfully!\n');

      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code}');
      print('📝 Message: ${e.message}\n');

      if (mounted) {
        String errorMessage = 'Failed to send message';
        
        if (e.code == 'permission-denied') {
          errorMessage = 'Permission denied. Check your access rights.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Network error. Please check your connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _messageController.text = text;
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Unexpected Error: $e\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                widget.hackerName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.hackerName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Security Expert',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // Handle errors
                if (snapshot.hasError) {
                  print('❌ Stream Error: ${snapshot.error}');
                  
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_person_rounded,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Access Denied",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Error: ${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                // Trigger rebuild to retry
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Show loading indicator
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Handle no data
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;

                // Empty state
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Secure connection established",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start consulting with ${widget.hackerName}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Display messages
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    try {
                      var data = docs[index].data() as Map<String, dynamic>;
                      bool isMe = data['senderId'] == _auth.currentUser!.uid;

                      // Get timestamp
                      String timeStr = '';
                      if (data['timestamp'] != null) {
                        Timestamp timestamp = data['timestamp'];
                        DateTime dateTime = timestamp.toDate();
                        timeStr = _formatTime(dateTime);
                      }

                      return _buildMessageBubble(
                        data['text'] ?? '',
                        isMe,
                        timeStr,
                      );
                    } catch (e) {
                      print('⚠️ Error parsing message: $e');
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // Format timestamp
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // Message bubble widget
  Widget _buildMessageBubble(String text, bool isMe, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 16,
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[700] : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Message input widget
  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[200]!),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: Colors.grey[100],
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[700],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}