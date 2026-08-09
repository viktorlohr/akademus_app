import 'package:meta/meta.dart';

/// Describes what a single study run should contain.
@immutable
class StudySessionConfig {
  final String title;
  final List<String> categories;

  /// Max cards to draw. `null` means "all available".
  final int? maxCards;

  /// Random order instead of weakest-proficiency-first.
  final bool shuffle;

  /// Whether the run produces a graded [SessionScore] that gets saved
  /// to history. Topic-tile practice does not.
  final bool rated;

  const StudySessionConfig({
    required this.title,
    required this.categories,
    this.maxCards,
    this.shuffle = false,
    this.rated = false,
  });

  /// Classic single-topic run: every card, weakest first, ungraded.
  StudySessionConfig.single(String category)
    : title = category,
      categories = [category],
      maxCards = null,
      shuffle = false,
      rated = false;
}
