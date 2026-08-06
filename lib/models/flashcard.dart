import 'package:meta/meta.dart';

/// A single flashcard. Front and back are always pre-rendered .webp
/// images (e.g. compiled LaTeX) bundled as assets — there is no text or
/// markdown content to parse or edit.
@immutable
class Flashcard {
  final String id;
  final String category;
  final String frontImage;
  final String backImage;

  const Flashcard({
    required this.id,
    required this.category,
    required this.frontImage,
    required this.backImage,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String,
      category: json['category'] as String,
      frontImage: json['front'] as String,
      backImage: json['back'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'front': frontImage,
    'back': backImage,
  };

  @override
  String toString() => 'Flashcard(id: $id, category: $category)';
}
