import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tutorial_main.dart';
import 'chat.dart';
import 'cam.dart';
import 'package:swift_aid/screens/ar_main.dart';
import 'tutorial_main.dart'; // Import your Tutorials screen
import 'chat.dart'; // Import your chatbot screen


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Function to call emergency number
  void _callEmergency() async {
    final Uri callUri = Uri(scheme: 'tel', path: '108');
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      debugPrint("Could not launch dialer");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF6C7A9C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Swift-Aid',
                  style: TextStyle(
                    fontSize: 26,
                    color: Color(0xFF1A202C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 40),

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FirstAidCamera(),
                    ));
                  },
                  // AR Guidance Card
                child: const FeatureCard(
                  icon: Icons.camera_alt_rounded,
                  iconColor: Color(0xFFFF9B9B),
                  title: 'AI/AR Camera Guidance',
                  subtitle: 'Real-time visual assistance',
                ),),
                const SizedBox(height: 20),

                // Tutorials Card 
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TutorialsScreen()),
                    );
                  },
                  child: const FeatureCard(
                    icon: Icons.menu_book_rounded,
                    iconColor: Color(0xFFB5D6FF),
                    title: 'Tutorials',
                    subtitle: 'Step-by-step instructions',
                  ),
                ),
                const SizedBox(height: 20),

                // Chatbot Assistant Card
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatPage()),
                    );
                  },
                  child: const FeatureCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: Color(0xFFC5E7C7),
                    title: 'Chatbot Assistant',
                    subtitle: 'Instant help and guidance',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // 🆘 Floating SOS Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        onTap: _callEmergency,
        child: Container(
          height: 65,
          width: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFFF5C5C),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.phone_in_talk_rounded,
                  color: Colors.white, size: 26),
              SizedBox(width: 8),
              Text(
                'SOS - Call 108',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 30, color: iconColor.withOpacity(0.9)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A94A6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 18.0),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFE0E3EB),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}