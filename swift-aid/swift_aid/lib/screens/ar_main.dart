import 'package:flutter/material.dart';
import 'package:swift_aid/screens/ar_screens/ar_arm_sling.dart';
import 'package:swift_aid/screens/ar_screens/ar_choking.dart';
import 'package:swift_aid/screens/ar_screens/ar_cpr.dart';
import 'package:swift_aid/screens/ar_screens/ar_hand_bleed.dart';
import 'package:swift_aid/screens/ar_screens/ar_leg_sprain.dart';
import 'package:swift_aid/screens/ar_screens/ar_nose_bleed.dart';

class ARTutorialsScreen extends StatefulWidget {
  const ARTutorialsScreen({super.key});

  @override
  State<ARTutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<ARTutorialsScreen> {
  final List<Map<String, dynamic>> _tutorials = [
    {
      'icon': Icons.favorite_border_rounded,
      'iconColor': const Color(0xFFFF9B9B),
      'title': 'CPR',
      'onTap': (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ARcprWidget()),
        );
      },
    },
    {
      'icon': Icons.air_rounded,
      'iconColor': const Color(0xFFB5D6FF),
      'title': 'Choking',
      'onTap': (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ARChokingWidget ()),
        );
      },
    },
    {
      'icon': Icons.bloodtype_rounded,
      'iconColor': const Color(0xFFFFB6B6),
      'title': 'Nose Bleed',
      'onTap': (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ARNoseBleedWidget ()),
        );
      },
    },
    {
      'icon': Icons.directions_walk_rounded,
      'iconColor': const Color(0xFFB5D6FF),
      'title': 'Leg Sprain',
      'onTap': (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ARLegSprainWidget ()),
        );
      },
    },
    {
      'icon': Icons.bloodtype_rounded,
      'iconColor': const Color(0xFFD7C8FF),
      'title': 'Hand Bleed',
      'onTap': (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ARHandBleedWidget ()),
        );
      },
    },
    {
      'icon': Icons.front_hand,
      'iconColor': const Color(0xFFB5D6FF),
      'title': 'Arm Sling',
      'onTap': (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ARArmSlingWidget ()),
        );
      },
    },
  ];

  late List<Map<String, dynamic>> _filteredTutorials;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredTutorials = List.from(_tutorials);
  }

  void _filterTutorials(String query) {
    final filtered = _tutorials.where((item) {
      final title = item['title'].toString().toLowerCase();
      return title.contains(query.toLowerCase());
    }).toList();

    setState(() => _filteredTutorials = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI/AR Guidance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterTutorials,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search AI/AR Guidance',
                    hintStyle: TextStyle(
                      color: Color(0xFF8A94A6),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF8A94A6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              Expanded(
                child: _filteredTutorials.isEmpty
                    ? const Center(
                        child: Text(
                          'No AR Guidance found.',
                          style: TextStyle(
                            color: Color(0xFF8A94A6),
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredTutorials.length,
                        itemBuilder: (context, index) {
                          final item = _filteredTutorials[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18.0),
                            child: GestureDetector(
                              onTap: () {
                                final onTap =
                                    item['onTap'] as void Function(BuildContext)?;
                                if (onTap != null) onTap(context);
                              },
                              child: TutorialCard(
                                icon: item['icon'] as IconData,
                                iconColor: item['iconColor'] as Color,
                                title: item['title'] as String,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TutorialCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const TutorialCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A202C),
              ),
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
