// lib/presentation/screens/quiz_screen.dart
import 'package:flutter/material.dart';
import '../../models/quiz_question.dart';
import '../../models/session_score.dart';
import '../../models/study_session_config.dart';
import '../../services/quiz_service.dart';
import '../../storage/session_history_storage.dart';
import '../widgets/app_chrome.dart';
import '../widgets/rich_content.dart';
import 'stats_screen.dart';

class QuizScreen extends StatefulWidget {
  final StudySessionConfig config;

  const QuizScreen({super.key, required this.config});

  // Unlike FlashcardScreen.category, this doesn't reuse
  // StudySessionConfig.single: that factory hard-codes shuffle: false,
  // which for flashcards drives weakest-proficiency-first ordering. Quiz
  // has no proficiency weighting, so topic-tile practice should just
  // shuffle rather than replay questions in manifest order every time.
  QuizScreen.category(String category, {super.key})
    : config = StudySessionConfig(
        title: category,
        categories: [category],
        shuffle: true,
      );

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _quizService = QuizService();
  final _history = SessionHistoryStorage();
  final _answerController = TextEditingController();

  List<QuizQuestion> _questions = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  final Set<String> _selectedOptionIds = {};

  /// Null until the current question has been checked.
  bool? _wasCorrect;

  int _knownCount = 0;
  int _unknownCount = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;
  bool _isFinishing = false;
  final Map<String, int> _categoryTotals = {};
  final Map<String, int> _categoryKnown = {};

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);
  final Color myGreen = const Color(0xFF2E7D32);
  final Color myRed = const Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final questions = await _quizService.getQuestionsForSession(
      widget.config,
    );
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  QuizQuestion get _current => _questions[_currentIndex];

  bool get _canCheck {
    switch (_current.type) {
      case QuestionType.singleChoice:
      case QuestionType.multipleChoice:
        return _selectedOptionIds.isNotEmpty;
      case QuestionType.shortAnswer:
        return _answerController.text.trim().isNotEmpty;
    }
  }

  void _toggleOption(String optionId) {
    if (_wasCorrect != null) return;
    setState(() {
      if (_current.type == QuestionType.singleChoice) {
        _selectedOptionIds
          ..clear()
          ..add(optionId);
      } else {
        if (!_selectedOptionIds.remove(optionId)) {
          _selectedOptionIds.add(optionId);
        }
      }
    });
  }

  void _check() {
    final correct = _current.isCorrect(
      selectedOptionIds: _selectedOptionIds,
      typedAnswer: _answerController.text,
    );
    final category = _current.category;
    setState(() {
      _wasCorrect = correct;
      _categoryTotals[category] = (_categoryTotals[category] ?? 0) + 1;
      if (correct) {
        _knownCount++;
        _currentStreak++;
        if (_currentStreak > _maxStreak) _maxStreak = _currentStreak;
        _categoryKnown[category] = (_categoryKnown[category] ?? 0) + 1;
      } else {
        _unknownCount++;
        _currentStreak = 0;
      }
    });
  }

  Future<void> _next() async {
    final isLast = _currentIndex == _questions.length - 1;
    if (!isLast) {
      setState(() {
        _currentIndex++;
        _selectedOptionIds.clear();
        _answerController.clear();
        _wasCorrect = null;
      });
      return;
    }

    if (_isFinishing) return;
    _isFinishing = true;

    final score = SessionScore(
      title: widget.config.title,
      categories: widget.config.categories,
      total: _questions.length,
      known: _knownCount,
      maxStreak: _maxStreak,
      finishedAt: DateTime.now(),
      mode: SessionMode.quiz,
      categoryTotals: _categoryTotals,
      categoryKnown: _categoryKnown,
    );

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
          onRetry: (_) => QuizScreen(config: widget.config),
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

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.config.title)),
        body: const Center(child: Text('Keine Fragen für dieses Thema.')),
      );
    }

    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
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
      body: AppBackground(
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
              const SizedBox(height: 8),
              Text(
                '${_currentIndex + 1}/${_questions.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: RichContent(
                          _current.prompt,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AnswerArea(
                        question: _current,
                        selectedOptionIds: _selectedOptionIds,
                        answerController: _answerController,
                        wasCorrect: _wasCorrect,
                        onToggleOption: _toggleOption,
                        onAnswerChanged: () => setState(() {}),
                        myBlue: myBlue,
                        myGreen: myGreen,
                        myRed: myRed,
                      ),
                      if (_wasCorrect != null && _current.explanation != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: myBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: myBlue.withValues(alpha: 0.2)),
                          ),
                          child: RichContent(_current.explanation!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _CompactStat(icon: Icons.check_circle, label: '$_knownCount', color: myGreen),
                  const SizedBox(width: 8),
                  _CompactStat(icon: Icons.local_fire_department, label: '$_currentStreak', color: myOrange),
                  const SizedBox(width: 8),
                  _CompactStat(icon: Icons.cancel, label: '$_unknownCount', color: myRed),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _wasCorrect == null
                        ? (_canCheck ? _check : null)
                        : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: myBlue,
                      foregroundColor: myOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _wasCorrect == null
                          ? 'Prüfen'
                          : (_currentIndex == _questions.length - 1 ? 'Fertig' : 'Weiter'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ANSWER AREA ─────────────────────────────────────────────────────────────

class _AnswerArea extends StatelessWidget {
  final QuizQuestion question;
  final Set<String> selectedOptionIds;
  final TextEditingController answerController;
  final bool? wasCorrect;
  final ValueChanged<String> onToggleOption;
  final VoidCallback onAnswerChanged;
  final Color myBlue;
  final Color myGreen;
  final Color myRed;

  const _AnswerArea({
    required this.question,
    required this.selectedOptionIds,
    required this.answerController,
    required this.wasCorrect,
    required this.onToggleOption,
    required this.onAnswerChanged,
    required this.myBlue,
    required this.myGreen,
    required this.myRed,
  });

  @override
  Widget build(BuildContext context) {
    if (question.type == QuestionType.shortAnswer) {
      return TextField(
        controller: answerController,
        enabled: wasCorrect == null,
        onChanged: (_) => onAnswerChanged(),
        decoration: InputDecoration(
          hintText: 'Antwort eingeben...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          suffixIcon: wasCorrect == null
              ? null
              : Icon(
                  wasCorrect! ? Icons.check_circle : Icons.cancel,
                  color: wasCorrect! ? myGreen : myRed,
                ),
        ),
      );
    }

    return Column(
      children: [
        for (final option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              option: option,
              selected: selectedOptionIds.contains(option.id),
              revealed: wasCorrect != null,
              multiSelect: question.type == QuestionType.multipleChoice,
              onTap: () => onToggleOption(option.id),
              myBlue: myBlue,
              myGreen: myGreen,
              myRed: myRed,
            ),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final QuizOption option;
  final bool selected;
  final bool revealed;
  final bool multiSelect;
  final VoidCallback onTap;
  final Color myBlue;
  final Color myGreen;
  final Color myRed;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.revealed,
    required this.multiSelect,
    required this.onTap,
    required this.myBlue,
    required this.myGreen,
    required this.myRed,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.grey.shade300;
    Color? fillColor = Colors.white;
    IconData? trailingIcon;
    Color? trailingColor;

    if (revealed) {
      if (option.isCorrect) {
        borderColor = myGreen;
        fillColor = myGreen.withValues(alpha: 0.08);
        trailingIcon = Icons.check_circle;
        trailingColor = myGreen;
      } else if (selected) {
        borderColor = myRed;
        fillColor = myRed.withValues(alpha: 0.08);
        trailingIcon = Icons.cancel;
        trailingColor = myRed;
      }
    } else if (selected) {
      borderColor = myBlue;
      fillColor = myBlue.withValues(alpha: 0.06);
    }

    return InkWell(
      onTap: revealed ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              multiSelect
                  ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                  : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
              color: selected ? myBlue : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: RichContent(option.text)),
            if (trailingIcon != null) Icon(trailingIcon, color: trailingColor),
          ],
        ),
      ),
    );
  }
}

// ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactStat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
