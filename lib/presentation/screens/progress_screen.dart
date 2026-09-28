import 'package:flutter/material.dart';
import '../../models/session_score.dart';
import '../../services/progress_stats_service.dart';
import '../../storage/session_history_storage.dart';
import '../../constants/categories.dart';
import '../widgets/app_chrome.dart';
import '../widgets/category_progress_chart.dart';

/// "Lern-Statistiken": long-term progress across every rated session
/// (flashcards and quiz alike — they share one [SessionHistoryStorage], see
/// CLAUDE.md's Quiz feature section). The day-streak is a shared header
/// (it's derived from both modes together, see [ProgressStatsService.
/// buildStreak]); everything else — including "Letzte Sessions" — is split
/// into a swipeable Karteikarten/Quiz pair of sub-views, each backed by its
/// own mode-scoped [ProgressStats].
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);

  // Per-category colors for the "Entwicklung" chart's lines, plus a
  // separate color for the blended "Gesamt" line — distinct from myBlue/
  // myOrange's other UI uses so all four lines stay visually distinct.
  static const _analysisColor = Color(0xFFF5AC26);
  static const _geometrieColor = Color(0xFF264358);
  static const _stochastikColor = Color(0xFF2E7D32);
  static const _gesamtColor = Color(0xFF5C6B73);
  static const _categoryColors = <String, Color>{
    'Analysis': _analysisColor,
    'Geometrie': _geometrieColor,
    'Stochastik': _stochastikColor,
    'Gesamt': _gesamtColor,
  };

  final _history = SessionHistoryStorage();
  late final TabController _tabController;
  late Future<_ProgressData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_ProgressData> _load() async {
    final sessions = await _history.getAll();
    final service = ProgressStatsService();
    return _ProgressData(
      streak: service.buildStreak(sessions),
      flashcards: service.build(sessions, mode: SessionMode.flashcard),
      quiz: service.build(sessions, mode: SessionMode.quiz),
      flashcardQuestionTrends:
          service.buildQuestionTrends(sessions, mode: SessionMode.flashcard),
      quizQuestionTrends: service.buildQuestionTrends(sessions, mode: SessionMode.quiz),
      isEmpty: sessions.isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/akademus_logo.jpg',
          height: 80,
          fit: BoxFit.contain,
        ),
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: AppBackground(
        child: FutureBuilder<_ProgressData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            if (data.isEmpty) return _buildEmptyState(context);
            return _buildStats(context, data);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_chart_outlined, size: 56, color: myBlue),
            const SizedBox(height: 16),
            Text(
              'Noch keine Statistiken',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: myBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schließe eine bewertete Session bei den Karteikarten oder im '
              'Quiz ab, um hier deinen Fortschritt zu sehen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, _ProgressData data) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _streakCard(data.streak),
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: myBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(4),
            dividerColor: Colors.transparent,
            labelColor: myOrange,
            unselectedLabelColor: myBlue,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Karteikarten'),
              Tab(text: 'Quiz'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildModeStats(
                data.flashcards,
                questionTrends: data.flashcardQuestionTrends,
                emptyHint: 'Schließe eine bewertete Karteikarten-Session ab, um hier '
                    'deinen Fortschritt zu sehen.',
              ),
              _buildModeStats(
                data.quiz,
                questionTrends: data.quizQuestionTrends,
                emptyHint: 'Schließe ein bewertetes Quiz ab, um hier deinen '
                    'Fortschritt zu sehen.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeStats(
    ProgressStats stats, {
    required QuestionTrends questionTrends,
    required String emptyHint,
  }) {
    if (stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryTiles(stats),
          const SizedBox(height: 14),
          _trendCard(questionTrends),
          if (stats.categoryBreakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            _categoryCard(stats),
          ],
          const SizedBox(height: 14),
          _recentSessionsCard(stats),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );

  Widget _streakCard(StreakStats streak) {
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    // Weekday (0 = Monday) of the strip's first (oldest) day, 6 days before today.
    final startWeekday = (DateTime.now().weekday - 1 - 6) % 7;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: myBlue, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                streak.currentStreak > 0 ? '🔥' : '💤',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.currentStreak} ${streak.currentStreak == 1 ? 'Tag' : 'Tage'} in Folge',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: myOrange,
                    ),
                  ),
                  Text(
                    'Beste Serie: ${streak.longestStreak} '
                    '${streak.longestStreak == 1 ? 'Tag' : 'Tage'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  if (streak.currentStreakStartDate != null)
                    Text(
                      'Streak begonnen am: '
                      '${_formatDate(streak.currentStreakStartDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final active = streak.last7Days[i];
              final isToday = i == 6;
              final label = weekdays[(startWeekday + i) % 7];
              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? myOrange : Colors.white.withValues(alpha: 0.12),
                      border: isToday
                          ? Border.all(color: Colors.white, width: 1.5)
                          : null,
                    ),
                    child: active
                        ? Icon(Icons.local_fire_department, size: 16, color: myBlue)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _summaryTiles(ProgressStats stats) {
    Widget tile(String value, String label) => Expanded(
      child: _card(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: myBlue),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        tile('${stats.totalSessions}', 'Sessions'),
        const SizedBox(width: 10),
        tile('${stats.totalQuestions}', 'Beantwortet'),
        const SizedBox(width: 10),
        tile('${(stats.overallAccuracy * 100).round()}%', 'Ø Genauigkeit'),
      ],
    );
  }

  Widget _trendCard(QuestionTrends questionTrends) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entwicklung',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: myBlue),
          ),
          const SizedBox(height: 4),
          Text(
            'Richtige Antworten je Session, nach Anzahl beantworteter Fragen.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          if (questionTrends.overall.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nach der nächsten Session siehst du hier deine Entwicklung.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            )
          else
            CategoryProgressChart(
              maxX: questionTrends.totalQuestions,
              series: [
                for (final label in flashcardCategoryLabels)
                  _categorySeries(label, _categoryColors[label]!, questionTrends),
                QuestionTrendSeries(
                  label: 'Gesamt',
                  color: _gesamtColor,
                  points: [
                    for (final p in questionTrends.overall)
                      (
                        questionsAnswered: p.questionsAnswered,
                        percent: p.accuracy * 100,
                        total: p.cumulativeTotal,
                        known: p.cumulativeKnown,
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  QuestionTrendSeries _categorySeries(String label, Color color, QuestionTrends questionTrends) {
    final points = questionTrends.byCategory[label] ?? const [];
    return QuestionTrendSeries(
      label: label,
      color: color,
      points: [
        for (final p in points)
          (
            questionsAnswered: p.questionsAnswered,
            percent: p.accuracy * 100,
            total: p.cumulativeTotal,
            known: p.cumulativeKnown,
          ),
      ],
    );
  }

  Widget _categoryCard(ProgressStats stats) {
    // Same four series as the "Entwicklung" chart above (one bar per
    // category plus a "Gesamt" bar), so both sections show the same four
    // things.
    final bars = [
      ...stats.categoryBreakdown,
      CategoryBreakdown(
        category: 'Gesamt',
        accuracy: stats.overallAccuracy,
        sessionCount: stats.totalSessions,
      ),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nach Thema',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: myBlue),
          ),
          const SizedBox(height: 14),
          for (final c in bars) ...[
            _categoryBar(c),
            if (c != bars.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _categoryBar(CategoryBreakdown c) {
    // Same color as this category's line in the "Entwicklung" chart above,
    // so the two sections read as one consistent picture.
    final color = _categoryColors[c.category] ?? myBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              c.category,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
            Text(
              '${(c.accuracy * 100).round()}% · ${c.sessionCount} '
              '${c.sessionCount == 1 ? 'Session' : 'Sessions'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: c.accuracy,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _recentSessionsCard(ProgressStats stats) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Letzte Sessions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: myBlue),
          ),
          const SizedBox(height: 8),
          for (final s in stats.recentSessions) _recentSessionRow(s),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Widget _recentSessionRow(SessionScore s) {
    final dateStr = _formatDate(s.finishedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '${s.percent}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: myBlue),
          ),
        ],
      ),
    );
  }
}

class _ProgressData {
  final StreakStats streak;
  final ProgressStats flashcards;
  final ProgressStats quiz;
  final QuestionTrends flashcardQuestionTrends;
  final QuestionTrends quizQuestionTrends;
  final bool isEmpty;

  const _ProgressData({
    required this.streak,
    required this.flashcards,
    required this.quiz,
    required this.flashcardQuestionTrends,
    required this.quizQuestionTrends,
    required this.isEmpty,
  });
}
