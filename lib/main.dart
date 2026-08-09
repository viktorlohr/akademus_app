import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'presentation/screens/topic_selection_screen.dart';
import 'presentation/screens/quiz_topic_selection_screen.dart';
import 'presentation/widgets/app_chrome.dart';

/// Temporary pointer at the deployed quiz-editor admin page (see
/// firebase.json's /edit-quiz rewrite). Points at a specific Firebase
/// project's domain, so update this if hosting ever moves.
const String kQuizEditorUrl =
    'https://akademus-app-preview.web.app/edit-quiz/';

void main() => runApp(const MaterialApp(home: HomeScreen()));

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/akademus_logo.jpg',
          height: 80,
          fit: BoxFit.contain,
        ),
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: myOrange,
      ),
      body: GlobalFooterWrapper(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/background_female.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(color: Colors.white.withValues(alpha: 0.8)),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Willkommen!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: myBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Was möchtest du heute tun?',
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 40),
                  const MenuButton(
                    label: 'Mathe Karteikarten',
                    icon: Icons.style_outlined,
                    destination: TopicSelectionScreen(),
                  ),
                  const SizedBox(height: 16),
                  const MenuButton(
                    label: 'Quiz',
                    icon: Icons.quiz_outlined,
                    destination: QuizTopicSelectionScreen(),
                  ),
                  const SizedBox(height: 16),
                  const MenuButton(
                    label: 'Lern-Statistiken',
                    icon: Icons.insert_chart_outlined,
                    destination: PlaceholderScreen(title: ''),
                  ),
                  const SizedBox(height: 24),
                  const QuizEditorNoticeBox(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PLACEHOLDER SCREEN ──────────────────────────────────────────────────────

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/akademus_logo.jpg',
          height: 80,
          fit: BoxFit.contain,
        ),
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: AppBackground(child: Center(child: Text('$title kommt bald!'))),
    );
  }
}

// ─── QUIZ EDITOR NOTICE ──────────────────────────────────────────────────────

class QuizEditorNoticeBox extends StatelessWidget {
  const QuizEditorNoticeBox({super.key});

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);

  Future<void> _open() =>
      launchUrl(Uri.parse(kQuizEditorUrl), webOnlyWindowName: '_blank');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: myOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'So sieht der Quizeditor aus',
                      style: TextStyle(
                        color: myBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new, color: myBlue, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── SHARED BACKGROUND ───────────────────────────────────────────────────────

class MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget destination;
  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF264358),
          foregroundColor: const Color(0xFFF5AC26),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
