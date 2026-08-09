import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../models/quiz_question.dart';
import 'question_repository.dart';

/// Web-only: "loading" means the user picks a `.json` file (e.g. the
/// existing `assets/quiz_manifest.json`) via the browser's file dialog,
/// "saving" triggers a browser download of the current set. This admin
/// page only ever runs as a Flutter Web build, so browser APIs are fine
/// here — via `package:web` rather than the deprecated `dart:html`, so
/// this still compiles under `flutter build web --wasm`.
class JsonQuestionRepository implements QuestionRepository {
  @override
  Future<List<QuizQuestion>> loadAll() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json';

    final changed = input.onChange.first;
    input.click();
    await changed;

    final files = input.files;
    if (files == null || files.length == 0) return [];
    final file = files.item(0)!;

    final reader = web.FileReader();
    // FileReader has no `onLoad` extension getter in package:web (unlike
    // Element/XMLHttpRequest); go through the generic provider instead.
    final loaded = web.EventStreamProviders.loadEvent.forTarget(reader).first;
    reader.readAsText(file);
    await loaded;

    final text = (reader.result! as JSString).toDart;
    final decoded = jsonDecode(text) as List;
    return decoded
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveAll(List<QuizQuestion> questions) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(questions.map((q) => q.toJson()).toList());

    final blob = web.Blob(
      [jsonString.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = 'quiz_manifest.json'
      ..click();
    web.URL.revokeObjectURL(url);
  }
}
