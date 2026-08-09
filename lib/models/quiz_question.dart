import 'package:meta/meta.dart';

/// How a question is answered and graded. Kept small on purpose — this is
/// a prototype of the quiz content model, not a full Moodle question bank.
enum QuestionType {
  /// Exactly one correct option.
  singleChoice,

  /// One or more correct options; all must be picked, none extra.
  multipleChoice,

  /// Free-text answer matched case-insensitively against [QuizQuestion.acceptedAnswers].
  shortAnswer,
}

/// One selectable option for a (single/multiple) choice question.
@immutable
class QuizOption {
  final String id;
  final String text;
  final bool isCorrect;

  const QuizOption({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
    id: json['id'] as String,
    text: json['text'] as String,
    isCorrect: json['isCorrect'] as bool? ?? false,
  );
}

/// A single quiz question. [prompt] and [explanation] are plain strings
/// containing Markdown, with LaTeX math delimited by `$...$` (inline) or
/// `$$...$$` (block) — see RichContent for how that gets rendered.
///
/// Independent of Flashcard on purpose: flashcards are pre-rendered image
/// pairs baked from a LaTeX build step, quizzes are editable text content
/// rendered live. Sharing a model would force one side to fake the other's
/// shape.
@immutable
class QuizQuestion {
  final String id;
  final String category;
  final QuestionType type;
  final String prompt;
  final List<QuizOption> options;

  /// Only used by [QuestionType.shortAnswer]. Matched case-insensitively,
  /// whitespace-trimmed; any one match counts as correct.
  final List<String> acceptedAnswers;

  /// Optional Markdown/LaTeX shown after the user answers.
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.category,
    required this.type,
    required this.prompt,
    this.options = const [],
    this.acceptedAnswers = const [],
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final type = QuestionType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => throw FormatException('Unknown question type: ${json['type']}'),
    );
    return QuizQuestion(
      id: json['id'] as String,
      category: json['category'] as String,
      type: type,
      prompt: json['prompt'] as String,
      options: (json['options'] as List? ?? [])
          .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      acceptedAnswers: (json['acceptedAnswers'] as List? ?? []).cast<String>(),
      explanation: json['explanation'] as String?,
    );
  }

  /// Grades a set of selected option ids (choice types) or a single typed
  /// string (short answer, ignored for choice types).
  bool isCorrect({Set<String> selectedOptionIds = const {}, String? typedAnswer}) {
    switch (type) {
      case QuestionType.singleChoice:
        if (selectedOptionIds.length != 1) return false;
        return options
            .where((o) => o.isCorrect)
            .map((o) => o.id)
            .toSet()
            .containsAll(selectedOptionIds);
      case QuestionType.multipleChoice:
        final correctIds = options
            .where((o) => o.isCorrect)
            .map((o) => o.id)
            .toSet();
        return selectedOptionIds.length == correctIds.length &&
            selectedOptionIds.containsAll(correctIds);
      case QuestionType.shortAnswer:
        final typed = typedAnswer?.trim().toLowerCase();
        if (typed == null || typed.isEmpty) return false;
        return acceptedAnswers.any((a) => a.trim().toLowerCase() == typed);
    }
  }
}
