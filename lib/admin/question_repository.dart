import '../models/quiz_question.dart';

/// Where the admin page reads/writes the question set. [JsonQuestionRepository]
/// is the only implementation today — it round-trips a file the user picks
/// and downloads. Swapping to Firebase later means writing a
/// `FirestoreQuestionRepository` with the same two methods and changing one
/// constructor call in [AdminHomeScreen]; nothing else in the admin UI
/// depends on how the data is actually stored.
abstract class QuestionRepository {
  /// Fetches the current question set from wherever it lives.
  Future<List<QuizQuestion>> loadAll();

  /// Persists the full question set.
  Future<void> saveAll(List<QuizQuestion> questions);
}
