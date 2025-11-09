import 'package:flutter/material.dart';
import 'cpr_tutorial.dart'; // ✅ Import your CPR tutorial page

class TutorialsScreen extends StatefulWidget {
  const TutorialsScreen({super.key});

  @override
  State<TutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<TutorialsScreen> {
  // ✅ All tutorials
  final List<Map<String, dynamic>> _tutorials = [
    {
      'icon': Icons.favorite_border_rounded,
      'iconColor': const Color(0xFFFF9B9B),
      'title': 'CPR',
      'onTap': (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CPRTutorialScreen()),
        );
      },
    },
    {
      'icon': Icons.air_rounded,
      'iconColor': const Color(0xFFB5D6FF),
      'title': 'Choking',
      'onTap': null,
    },
    {
      'icon': Icons.bloodtype_rounded,
      'iconColor': const Color(0xFFFFB6B6),
      'title': 'Bleeding Control',
      'onTap': null,
    },
    {
      'icon': Icons.directions_walk_rounded,
      'iconColor': const Color(0xFFD7C8FF),
      'title': 'Ankle Sprain',
      'onTap': null,
    },
  ];

  // ✅ This list updates dynamically when searching
  late List<Map<String, dynamic>> _filteredTutorials;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredTutorials = List.from(_tutorials);
  }

  // ✅ Simple search filter
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
                'Tutorials',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Search Bar
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
                    hintText: 'Search first-aid steps...',
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

              // ✅ Scrollable tutorial list
              Expanded(
                child: _filteredTutorials.isEmpty
                    ? const Center(
                        child: Text(
                          'No tutorials found.',
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
