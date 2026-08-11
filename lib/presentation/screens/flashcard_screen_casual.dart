// lib/presentation/screens/flashcard_screen_casual.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/flashcard_service.dart';
import '../../models/study_session_config.dart';
import 'flashcard_screen.dart' show kCardAspectRatio;

/// Casual, ungraded browsing of a single category's flashcards — no
/// "knew it"/"didn't know" rating and no summary screen at the end.
/// Cards are ordered weakest-proficiency-first (via
/// [StudySessionConfig.single]) so casually opening a topic still
/// surfaces the cards the user struggles with most.
class FlashcardScreenCasual extends StatefulWidget {
  final String category;

  const FlashcardScreenCasual({super.key, required this.category});

  @override
  State<FlashcardScreenCasual> createState() => _FlashcardScreenCasualState();
}

class _FlashcardScreenCasualState extends State<FlashcardScreenCasual>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final _flashcardService = FlashcardService();

  List<StudyCard> _cards = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  bool _isFront = true;

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);

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
    final cards = await _flashcardService.getCardsForSession(
      StudySessionConfig.single(widget.category),
    );
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

  void _nextCard() {
    if (_currentIndex >= _cards.length - 1) return;
    setState(() {
      _currentIndex++;
      _isFront = true;
      _controller.reset();
    });
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 200) _nextCard();
  }

  void _goHome(BuildContext context) =>
      Navigator.popUntil(context, (route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category)),
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
          child: Text(widget.category, style: TextStyle(color: myBlue)),
        ),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: myOrange,
      ),
      body: Padding(
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLast ? null : _nextCard,
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Weiter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
