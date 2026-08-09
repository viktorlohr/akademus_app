import 'package:flutter/material.dart';
import '../models/quiz_question.dart';
import '../presentation/widgets/rich_content.dart';

class QuestionEditorForm extends StatefulWidget {
  final QuizQuestion? initial;
  final List<String> categories;
  final ValueChanged<QuizQuestion> onSave;
  final VoidCallback onCancel;

  const QuestionEditorForm({
    super.key,
    required this.initial,
    required this.categories,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<QuestionEditorForm> createState() => _QuestionEditorFormState();
}

class _OptionRow {
  final String id;
  final TextEditingController controller;
  bool isCorrect;
  _OptionRow({required this.id, required String text, this.isCorrect = false})
    : controller = TextEditingController(text: text);
}

class _QuestionEditorFormState extends State<QuestionEditorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _promptController;
  late final TextEditingController _explanationController;
  late String _category;
  late QuestionType _type;
  final List<_OptionRow> _optionRows = [];
  final List<TextEditingController> _acceptedAnswerControllers = [];

  String? _error;

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);
  final Color myGreen = const Color(0xFF2E7D32);
  final Color myRed = const Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _idController = TextEditingController(text: q?.id ?? '');
    _promptController = TextEditingController(text: q?.prompt ?? '')
      ..addListener(_refresh);
    _explanationController = TextEditingController(text: q?.explanation ?? '')
      ..addListener(_refresh);
    _category = q?.category ?? widget.categories.first;
    _type = q?.type ?? QuestionType.singleChoice;

    if (q != null && q.options.isNotEmpty) {
      for (final o in q.options) {
        _optionRows.add(
          _OptionRow(id: o.id, text: o.text, isCorrect: o.isCorrect),
        );
      }
    } else {
      _addOption();
      _addOption();
    }

    if (q != null && q.acceptedAnswers.isNotEmpty) {
      for (final a in q.acceptedAnswers) {
        _acceptedAnswerControllers.add(
          TextEditingController(text: a)..addListener(_refresh),
        );
      }
    } else {
      _acceptedAnswerControllers.add(
        TextEditingController()..addListener(_refresh),
      );
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _idController.dispose();
    _promptController.dispose();
    _explanationController.dispose();
    for (final row in _optionRows) {
      row.controller.dispose();
    }
    for (final c in _acceptedAnswerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _nextOptionId() {
    final used = _optionRows.map((r) => r.id).toSet();
    for (var i = 0; i < 26; i++) {
      final id = String.fromCharCode(97 + i);
      if (!used.contains(id)) return id;
    }
    return 'opt${_optionRows.length}';
  }

  void _addOption() {
    setState(
      () => _optionRows.add(_OptionRow(id: _nextOptionId(), text: '')),
    );
  }

  void _removeOption(_OptionRow row) {
    setState(() {
      _optionRows.remove(row);
      row.controller.dispose();
    });
  }

  void _addAcceptedAnswer() {
    setState(
      () => _acceptedAnswerControllers.add(
        TextEditingController()..addListener(_refresh),
      ),
    );
  }

  void _removeAcceptedAnswer(TextEditingController c) {
    setState(() {
      _acceptedAnswerControllers.remove(c);
      c.dispose();
    });
  }

  void _save() {
    setState(() => _error = null);
    if (_idController.text.trim().isEmpty) {
      setState(() => _error = 'Bitte eine ID vergeben.');
      return;
    }
    if (_promptController.text.trim().isEmpty) {
      setState(() => _error = 'Bitte eine Frage eingeben.');
      return;
    }

    final isChoice =
        _type == QuestionType.singleChoice ||
        _type == QuestionType.multipleChoice;

    if (isChoice) {
      final nonEmpty = _optionRows
          .where((r) => r.controller.text.trim().isNotEmpty)
          .toList();
      if (nonEmpty.length < 2) {
        setState(() => _error = 'Mindestens 2 Antwortoptionen nötig.');
        return;
      }
      if (!nonEmpty.any((r) => r.isCorrect)) {
        setState(
          () => _error = 'Mindestens eine Option muss richtig markiert sein.',
        );
        return;
      }
    } else {
      final nonEmpty = _acceptedAnswerControllers
          .where((c) => c.text.trim().isNotEmpty)
          .toList();
      if (nonEmpty.isEmpty) {
        setState(() => _error = 'Mindestens eine akzeptierte Antwort nötig.');
        return;
      }
    }

    final question = QuizQuestion(
      id: _idController.text.trim(),
      category: _category,
      type: _type,
      prompt: _promptController.text.trim(),
      options: isChoice
          ? _optionRows
                .where((r) => r.controller.text.trim().isNotEmpty)
                .map(
                  (r) => QuizOption(
                    id: r.id,
                    text: r.controller.text.trim(),
                    isCorrect: r.isCorrect,
                  ),
                )
                .toList()
          : const [],
      acceptedAnswers: isChoice
          ? const []
          : _acceptedAnswerControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
      explanation: _explanationController.text.trim().isEmpty
          ? null
          : _explanationController.text.trim(),
    );

    widget.onSave(question);
  }

  @override
  Widget build(BuildContext context) {
    final isChoice =
        _type == QuestionType.singleChoice ||
        _type == QuestionType.multipleChoice;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.initial == null ? 'Neue Frage' : 'Frage bearbeiten',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: myBlue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Thema',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in widget.categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<QuestionType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Fragetyp',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: QuestionType.singleChoice,
                child: Text('Einfachauswahl'),
              ),
              DropdownMenuItem(
                value: QuestionType.multipleChoice,
                child: Text('Mehrfachauswahl'),
              ),
              DropdownMenuItem(
                value: QuestionType.shortAnswer,
                child: Text('Kurzantwort'),
              ),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _promptController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Frage (Markdown + \$LaTeX\$ erlaubt)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          _PreviewBox(
            child: _promptController.text.trim().isEmpty
                ? const Text('Vorschau erscheint hier...')
                : RichContent(_promptController.text),
          ),
          const SizedBox(height: 20),
          if (isChoice) ...[
            Text(
              'Antwortoptionen',
              style: TextStyle(fontWeight: FontWeight.bold, color: myBlue),
            ),
            const SizedBox(height: 8),
            for (final row in _optionRows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: row.isCorrect,
                      activeColor: myGreen,
                      onChanged: (v) {
                        setState(() {
                          if (_type == QuestionType.singleChoice &&
                              v == true) {
                            for (final r in _optionRows) {
                              r.isCorrect = false;
                            }
                          }
                          row.isCorrect = v ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: row.controller,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Option ${row.id}',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: myRed),
                      onPressed: _optionRows.length > 2
                          ? () => _removeOption(row)
                          : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              label: const Text('Option hinzufügen'),
            ),
          ] else ...[
            Text(
              'Akzeptierte Antworten',
              style: TextStyle(fontWeight: FontWeight.bold, color: myBlue),
            ),
            const SizedBox(height: 4),
            Text(
              'Wird beim Prüfen case-insensitive verglichen.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            for (final c in _acceptedAnswerControllers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: c,
                        decoration: const InputDecoration(
                          hintText: 'z.B. 28.27',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: myRed),
                      onPressed: _acceptedAnswerControllers.length > 1
                          ? () => _removeAcceptedAnswer(c)
                          : null,
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: _addAcceptedAnswer,
              icon: const Icon(Icons.add),
              label: const Text('Antwort hinzufügen'),
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _explanationController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Erklärung (optional, Markdown + \$LaTeX\$)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_explanationController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _PreviewBox(child: RichContent(_explanationController.text)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: myRed)),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: myBlue,
                  foregroundColor: myOrange,
                ),
                child: const Text('Speichern'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final Widget child;
  const _PreviewBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
