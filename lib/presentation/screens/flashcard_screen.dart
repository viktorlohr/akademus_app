// lib/presentation/screens/flashcard_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/session_score.dart';
import '../../models/study_session_config.dart';
import '../../services/flashcard_service.dart';
import '../../storage/session_history_storage.dart';
import 'stats_screen.dart';

/// Must match paperwidth:paperheight in
/// flashcards_source/praeambel_app_standalone.tex (currently 105mm:148mm
/// - ISO A6). If those dimensions change, update this too, or the
/// .webp images will letterbox/pillarbox instead of filling the card
/// edge-to-edge.
const double kCardAspectRatio = 105 / 148;

class FlashcardScreen extends StatefulWidget {
  final StudySessionConfig config;

  const FlashcardScreen({super.key, required this.config});

  /// Casual, ungraded browsing of a single category — tapping a topic
  /// tile. No "knew it"/"didn't know" rating and no summary screen at
  /// the end, just a "Weiter" button advancing through the deck.
  FlashcardScreen.category(String category, {super.key})
    : config = StudySessionConfig.single(category);

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final _flashcardService = FlashcardService();
  final _history = SessionHistoryStorage();

  List<StudyCard> _cards = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  bool _isFront = true;

  int _knownCount = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;
  final Map<String, int> _categoryTotals = {};
  final Map<String, int> _categoryKnown = {};

  /// Guards against a second rating landing while the last card is still
  /// being persisted — swipe + button tap can otherwise both fire.
  bool _isFinishing = false;

  /// The only branch point between graded sessions (rating buttons,
  /// proficiency tracking, a [StatsScreen] at the end) and casual
  /// topic-tile browsing (a plain "Weiter" button, nothing recorded).
  bool get _graded => widget.config.rated;

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);
  final Color myGreen = const Color(0xFF2E7D32);
  final Color myRed = const Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _load();
  }

  Future<void> _load() async {
    final cards = await _flashcardService.getCardsForSession(widget.config);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (!_graded) {
      if (velocity.abs() > 200) _nextCard();
      return;
    }
    if (velocity < -200) {
      // Swiped Left -> Falsch / Wrong
      _rate(false);
    } else if (velocity > 200) {
      // Swiped Right -> Richtig / Correct
      _rate(true);
    }
  }

  /// Casual-mode advance: no rating, no proficiency update.
  void _nextCard() {
    if (_currentIndex >= _cards.length - 1) return;
    setState(() {
      _currentIndex++;
      _isFront = true;
      _controller.reset();
    });
  }

  Future<void> _rate(bool known) async {
    if (_isFinishing) return;
    if (_currentIndex >= _cards.length) return;
    final studyCard = _cards[_currentIndex];

    final isLast = _currentIndex == _cards.length - 1;
    if (isLast) _isFinishing = true;

    await _flashcardService.rateCard(studyCard.card.id, known);
    if (!mounted) return;

    final category = studyCard.card.category;
    _categoryTotals[category] = (_categoryTotals[category] ?? 0) + 1;
    if (known) {
      _knownCount++;
      _currentStreak++;
      if (_currentStreak > _maxStreak) _maxStreak = _currentStreak;
      _categoryKnown[category] = (_categoryKnown[category] ?? 0) + 1;
    } else {
      _currentStreak = 0;
    }

    if (!isLast) {
      setState(() {
        _currentIndex++;
        _isFront = true;
        _controller.reset();
      });
      return;
    }

    final score = SessionScore(
      title: widget.config.title,
      categories: widget.config.categories,
      total: _cards.length,
      known: _knownCount,
      maxStreak: _maxStreak,
      finishedAt: DateTime.now(),
      mode: SessionMode.flashcard,
      categoryTotals: _categoryTotals,
      categoryKnown: _categoryKnown,
    );

    // Only graded runs go into history; practice shouldn't pollute it.
    SessionScore? best;
    if (widget.config.rated) {
      best = await _history.bestFor(widget.config.categories);
      await _history.add(score);
    }
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          config: widget.config,
          score: score,
          previousBest: best,
          onRetry: (_) => FlashcardScreen(config: widget.config),
        ),
      ),
    );
  }

  void _goHome(BuildContext context) =>
      Navigator.popUntil(context, (route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.config.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.config.title)),
        body: const Center(child: Text("Keine Karten für dieses Thema.")),
      );
    }

    final studyCard = _cards[_currentIndex];
    final progress = (_currentIndex + 1) / _cards.length;
    final isLast = _currentIndex == _cards.length - 1;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _goHome(context),
          child: Text(widget.config.title, style: TextStyle(color: myBlue)),
        ),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: myOrange,
      ),
      // bottom: true keeps the Falsch/Richtig/Weiter buttons clear of
      // Android's gesture nav bar; top: false since the AppBar already
      // handles the top inset. This screen doesn't go through
      // GlobalFooterWrapper/AppBackground (no footer here), so it needs
      // its own SafeArea rather than inheriting one.
      body: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(myOrange),
                ),
              ),
              const SizedBox(height: 12),
              if (_graded)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // In a mixed session the deck title is generic, so
                      // show which topic the current card actually is.
                      widget.config.categories.length > 1
                          ? studyCard.card.category
                          : widget.config.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: myBlue,
                      ),
                    ),
                    Text(
                      '${_currentIndex + 1}/${_cards.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ],
                )
              else
                Text(
                  '${_currentIndex + 1}/${_cards.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: kCardAspectRatio,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        final angle = _animation.value * pi;
                        final showBack = angle > pi / 2;

                        Matrix4 perspective() =>
                            Matrix4.identity()..setEntry(3, 2, 0.001);

                        return Stack(
                          children: [
                            Visibility(
                              visible: !showBack,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: GestureDetector(
                                onTap: _flipCard,
                                onHorizontalDragEnd: _handleHorizontalDrag,
                                child: Transform(
                                  transform: perspective()..rotateY(angle),
                                  alignment: Alignment.center,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _CardImage(
                                      assetPath: studyCard.card.frontImage,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Visibility(
                              visible: showBack,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: GestureDetector(
                                onTap: _flipCard,
                                onHorizontalDragEnd: _handleHorizontalDrag,
                                child: Transform(
                                  transform: perspective()..rotateY(angle - pi),
                                  alignment: Alignment.center,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _CardImage(
                                      assetPath: studyCard.card.backImage,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_graded)
                AnimatedOpacity(
                  opacity: _isFront ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: _isFront,
                    child: Row(
                      children: [
                        Expanded(
                          child: _RatingButton(
                            label: 'Falsch',
                            icon: Icons.close,
                            color: myRed,
                            onPressed: () => _rate(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RatingButton(
                            label: 'Richtig',
                            icon: Icons.check,
                            color: myGreen,
                            onPressed: () => _rate(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLast ? null : _nextCard,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'Weiter',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: myBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ─── CARD IMAGE ──────────────────────────────────────────────────────────────

/// Renders one bundled .webp flashcard face. InteractiveViewer lets the
/// user pinch-zoom dense LaTeX renders instead of the old scroll-to-read
/// behavior that markdown text used.
class _CardImage extends StatelessWidget {
  final String assetPath;
  const _CardImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        maxScale: 3,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Bild konnte nicht geladen werden:\n$assetPath',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

class _RatingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _RatingButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
    );
  }
}
