// lib/screens/level_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../router/app_router.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  final List<Map<String, dynamic>> _levels = [
    {
      'id': 1,
      'name': 'First Steps',
      'difficulty': 'easy',
      'description': 'Learn to move forward',
      'icon': Icons.rocket_launch,
    },
    {
      'id': 2,
      'name': 'Making a Turn',
      'difficulty': 'easy',
      'description': 'Navigate a corner',
      'icon': Icons.turn_right,
    },
    {
      'id': 3,
      'name': 'The Square Dance',
      'difficulty': 'medium',
      'description': 'Use loops to trace a square',
      'icon': Icons.sync,
    },
    {
      'id': 4,
      'name': 'Shuttle Run',
      'difficulty': 'medium',
      'description': 'Go and return to start',
      'icon': Icons.compare_arrows,
    },
    {
      'id': 5,
      'name': "Don't Hit The Wall!",
      'difficulty': 'hard',
      'description': 'Use sensors to avoid obstacles',
      'icon': Icons.sensors,
    },
    {
      'id': 6,
      'name': 'The Maze',
      'difficulty': 'hard',
      'description': 'Navigate a complex maze',
      'icon': Icons.grid_on,
    },
  ];

  Map<int, List<bool>> _progress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _progress = {};
      for (var level in _levels) {
        _progress[level['id']] = [false, false, false, false];
      }
      _isLoading = false;
    });
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'hard':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  void _onLevelTap(int levelId) {
    Navigator.pushNamed(
      context,
      AppRoutes.webview,
      arguments: {'action': 'load_challenge', 'id': levelId.toString()},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Challenge Mode',
                    style: GoogleFonts.titanOne(
                      fontSize: 28,
                      color: const Color(0xFF41D8FF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Level Grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF41D8FF),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _levels.length,
                      itemBuilder: (context, index) {
                        final level = _levels[index];
                        final stars =
                            _progress[level['id']] ??
                            [false, false, false, false];
                        final earnedStars = stars.where((s) => s).length;

                        return _LevelCard(
                          level: level,
                          earnedStars: earnedStars,
                          totalStars: 4,
                          difficultyColor: _getDifficultyColor(
                            level['difficulty'],
                          ),
                          onTap: () => _onLevelTap(level['id']),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.earnedStars,
    required this.totalStars,
    required this.difficultyColor,
    required this.onTap,
  });

  final Map<String, dynamic> level;
  final int earnedStars;
  final int totalStars;
  final Color difficultyColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color.fromARGB(204, 26, 42, 79),
              const Color.fromARGB(230, 15, 26, 53),
            ],
          ),
          border: Border.all(
            color: Color.fromARGB(128, difficultyColor.red, difficultyColor.green, difficultyColor.blue), // ignore: deprecated_member_use
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(51, difficultyColor.red, difficultyColor.green, difficultyColor.blue), // ignore: deprecated_member_use
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Difficulty Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(51, difficultyColor.red, difficultyColor.green, difficultyColor.blue), // ignore: deprecated_member_use
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      level['icon'],
                      color: difficultyColor,
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      level['difficulty'].toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Level Name
              Text(
                level['name'],
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              Text(
                level['description'],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white70,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              Row(
                children: List.generate(
                  totalStars,
                  (index) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      index < earnedStars ? Icons.star : Icons.star_border,
                      color: index < earnedStars
                          ? const Color(0xFFFFD700)
                          : Colors.white30,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
