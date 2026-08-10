import 'dart:math';
import 'package:flutter/material.dart';
import '../../constants/categories.dart';
import '../../models/study_session_config.dart';
import '../../services/quiz_service.dart';
import '../widgets/app_chrome.dart';
import 'quiz_screen.dart';

/// Lets the user pick categories and a question limit before starting a
/// randomized ("rated") quiz session.
class QuizSessionSetupScreen extends StatefulWidget {
  const QuizSessionSetupScreen({super.key});

  @override
  State<QuizSessionSetupScreen> createState() =>
      _QuizSessionSetupScreenState();
}

class _QuizSessionSetupScreenState extends State<QuizSessionSetupScreen> {
  static const _step = 5;
  static const _defaultMax = 10;

  final _service = QuizService();

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);

  final Set<String> _selected = {...flashcardCategoryLabels};
  Map<String, int> _counts = {};
  bool _isLoading = true;
  int _maxCards = _defaultMax;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final counts = await _service.countByCategory();
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _isLoading = false;
    });
  }

  /// Questions available across the currently selected categories.
  int get _available => _selected.fold(0, (sum, c) => sum + (_counts[c] ?? 0));

  /// What the session will actually contain.
  int get _effectiveMax => min(_maxCards, _available);

  void _changeMax(int delta) {
    final upper = max(_available, _step);
    setState(() => _maxCards = (_maxCards + delta).clamp(_step, upper));
  }

  void _toggle(String category, bool on) {
    setState(() {
      if (on) {
        _selected.add(category);
      } else {
        _selected.remove(category);
      }
    });
  }

  void _start() {
    // Keep the canonical order from the constants file, not tap order.
    final categories = flashcardCategoryLabels
        .where(_selected.contains)
        .toList();
    final config = StudySessionConfig(
      title: categories.length == 1 ? categories.first : 'Gemischte Session',
      categories: categories,
      maxCards: _maxCards,
      shuffle: true,
      rated: true,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(config: config)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _selected.isNotEmpty && _available > 0;

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
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Quiz-Session zusammenstellen',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: myBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Themen',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: myBlue,
                            ),
                          ),
                          for (final category in flashcardCategories)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: myOrange,
                              checkColor: myBlue,
                              value: _selected.contains(category.label),
                              onChanged: (v) =>
                                  _toggle(category.label, v ?? false),
                              secondary: Icon(category.icon, color: myBlue),
                              title: Text(category.label),
                              subtitle: Text(
                                '${_counts[category.label] ?? 0} Fragen',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Anzahl Fragen',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: myBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _maxCards > _step
                                    ? () => _changeMax(-_step)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                color: myBlue,
                              ),
                              Text(
                                '$_effectiveMax',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: myBlue,
                                ),
                              ),
                              IconButton(
                                onPressed: _maxCards < _available
                                    ? () => _changeMax(_step)
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                                color: myBlue,
                              ),
                            ],
                          ),
                          Text(
                            '$_available Fragen verfügbar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: canStart ? _start : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        canStart
                            ? 'Los geht\'s ($_effectiveMax Fragen)'
                            : 'Mindestens ein Thema wählen',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myBlue,
                        foregroundColor: myOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
