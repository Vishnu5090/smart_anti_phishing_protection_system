import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart'; // Ensure this path is correct based on your file structure

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  // Helper function to launch the native phone dialer
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        debugPrint('Could not launch dialer for $phoneNumber');
      }
    } catch (e) {
      debugPrint('Error launching dialer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildExpertCard(
                  context,
                  name: "Vishnuvardhan k",
                  specialty: "Phishing Forensics",
                  rating: 4.9,
                  price: "\$25/session",
                  imageInitial: "A",
                  isOnline: true,
                  phoneNumber: "+1234567890",
                  hackerId: "hacker_alex",
                ),
                const SizedBox(height: 16),
                _buildExpertCard(
                  context,
                  name: "Varun",
                  specialty: "Network Security",
                  rating: 5.0,
                  price: "\$40/session",
                  imageInitial: "S",
                  isOnline: true,
                  phoneNumber: "+1987654321",
                  hackerId: "hacker_sarah",
                ),
                const SizedBox(height: 16),
                _buildExpertCard(
                  context,
                  name: "Mathan",
                  specialty: "Data Recovery",
                  rating: 4.8,
                  price: "\$30/session",
                  imageInitial: "M",
                  isOnline: false,
                  phoneNumber: "+1555010999",
                  hackerId: "hacker_marcus",
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expert Support',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect with verified Ethical Hackers for immediate security assistance.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertCard(
    BuildContext context, {
    required String name,
    required String specialty,
    required double rating,
    required String price,
    required String imageInitial,
    required bool isOnline,
    required String phoneNumber,
    required String hackerId,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(imageInitial,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800)),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(specialty,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.orange, size: 18),
                        Text(' $rating',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Text(price,
                            style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // MESSAGE BUTTON
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: "Message",
                  color: Colors.blue.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          hackerName: name,
                          hackerId: hackerId,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // CALL BUTTON WITH CONFIRMATION
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone_forwarded_rounded,
                  label: "Call Now",
                  color: Colors.green.shade600,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("Start Call?", style: TextStyle(fontWeight: FontWeight.bold)),
                        content: Text("Would you like to call $name for security assistance?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _makePhoneCall(phoneNumber);
                            },
                            child: const Text("Call", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}