import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../models/quiz_question.dart';
import 'json_question_repository.dart';
import 'question_editor_form.dart';
import 'question_repository.dart';

/// Question-bank editor. Talks to the question set only through
/// [QuestionRepository] — today that's [JsonQuestionRepository] (browser
/// file import/download), later a Firestore-backed implementation can
/// replace it without touching this screen.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final QuestionRepository _repository = JsonQuestionRepository();

  final List<QuizQuestion> _questions = [];
  QuizQuestion? _editingExisting;
  bool _isEditingNew = false;

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);
  final Color myRed = const Color(0xFFC62828);

  bool get _isEditorOpen => _isEditingNew || _editingExisting != null;

  List<QuizQuestion> get _sorted {
    final copy = [..._questions];
    copy.sort((a, b) {
      final byCategory = a.category.compareTo(b.category);
      return byCategory != 0 ? byCategory : a.id.compareTo(b.id);
    });
    return copy;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import() async {
    final loaded = await _repository.loadAll();
    if (loaded.isEmpty) return;
    setState(() {
      _questions
        ..clear()
        ..addAll(loaded);
      _editingExisting = null;
      _isEditingNew = false;
    });
    _snack('${loaded.length} Fragen geladen.');
  }

  Future<void> _export() async {
    if (_questions.isEmpty) {
      _snack('Keine Fragen zum Exportieren.');
      return;
    }
    await _repository.saveAll(_questions);
    _snack('quiz_manifest.json exportiert.');
  }

  void _startNew() {
    setState(() {
      _isEditingNew = true;
      _editingExisting = null;
    });
  }

  void _edit(QuizQuestion question) {
    setState(() {
      _editingExisting = question;
      _isEditingNew = false;
    });
  }

  void _delete(QuizQuestion question) {
    setState(() {
      _questions.removeWhere((q) => q.id == question.id);
      if (_editingExisting?.id == question.id) {
        _editingExisting = null;
      }
    });
  }

  void _closeEditor() {
    setState(() {
      _isEditingNew = false;
      _editingExisting = null;
    });
  }

  void _save(QuizQuestion question) {
    setState(() {
      _questions.removeWhere((q) => q.id == question.id);
      _questions.add(question);
      _editingExisting = question;
      _isEditingNew = false;
    });
    _snack('Frage "${question.id}" gespeichert.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akademus Quiz Admin'),
        backgroundColor: myBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'JSON importieren',
            onPressed: _import,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Als JSON exportieren',
            onPressed: _export,
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Neue Frage'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myOrange,
                        foregroundColor: myBlue,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _questions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Noch keine Fragen. Importiere eine bestehende '
                              'quiz_manifest.json oder erstelle eine neue Frage.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final q in _sorted)
                              _QuestionListTile(
                                question: q,
                                selected: _editingExisting?.id == q.id,
                                onTap: () => _edit(q),
                                onDelete: () => _delete(q),
                                accentColor: myBlue,
                                deleteColor: myRed,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _isEditorOpen
                ? QuestionEditorForm(
                    key: ValueKey(_editingExisting?.id ?? '__new__'),
                    initial: _editingExisting,
                    categories: flashcardCategoryLabels,
                    onSave: _save,
                    onCancel: _closeEditor,
                  )
                : Center(
                    child: Text(
                      'Frage auswählen oder "Neue Frage" klicken.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuestionListTile extends StatelessWidget {
  final QuizQuestion question;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Color accentColor;
  final Color deleteColor;

  const _QuestionListTile({
    required this.question,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    required this.accentColor,
    required this.deleteColor,
  });

  String get _typeLabel {
    switch (question.type) {
      case QuestionType.singleChoice:
        return 'Einfachauswahl';
      case QuestionType.multipleChoice:
        return 'Mehrfachauswahl';
      case QuestionType.shortAnswer:
        return 'Kurzantwort';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: accentColor.withValues(alpha: 0.08),
      onTap: onTap,
      title: Text(
        question.id,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${question.category} · $_typeLabel\n${question.prompt}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: deleteColor),
        onPressed: onDelete,
      ),
    );
  }
}
