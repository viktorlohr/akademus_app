import 'package:flutter/material.dart';
import '../../models/session_score.dart';
import '../../services/progress_stats_service.dart';
import '../../storage/session_history_storage.dart';
import '../widgets/app_chrome.dart';
import '../widgets/trend_line_chart.dart';

enum _Metric { accuracy, points }

/// "Lern-Statistiken": long-term progress across every rated session
/// (flashcards and quiz alike — they share one [SessionHistoryStorage], see
/// CLAUDE.md's Quiz feature section), plus a day-streak derived from the
/// same history.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);
  final Color myGreen = const Color(0xFF2E7D32);
  final Color myRed = const Color(0xFFC62828);

  final _history = SessionHistoryStorage();
  late Future<ProgressStats> _statsFuture;
  _Metric _metric = _Metric.accuracy;

  @override
  void initState() {
    super.initState();
    _statsFuture = _load();
  }

  Future<ProgressStats> _load() async {
    final sessions = await _history.getAll();
    return ProgressStatsService().build(sessions);
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':
      case 'B':
        return myGreen;
      case 'C':
        return myOrange;
      default:
        return myRed;
    }
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
        child: FutureBuilder<ProgressStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = snapshot.data!;
            if (stats.isEmpty) return _buildEmptyState(context);
            return _buildStats(context, stats);
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

  Widget _buildStats(BuildContext context, ProgressStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _streakCard(stats),
          const SizedBox(height: 14),
          _summaryTiles(stats),
          const SizedBox(height: 14),
          _trendCard(stats),
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

  Widget _streakCard(ProgressStats stats) {
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
                stats.currentStreak > 0 ? '🔥' : '💤',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stats.currentStreak} ${stats.currentStreak == 1 ? 'Tag' : 'Tage'} in Folge',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: myOrange,
                    ),
                  ),
                  Text(
                    'Beste Serie: ${stats.longestStreak} '
                    '${stats.longestStreak == 1 ? 'Tag' : 'Tage'}',
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
              final active = stats.last7Days[i];
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

  Widget _trendCard(ProgressStats stats) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Entwicklung',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: myBlue),
              ),
              _metricToggle(),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.trend.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nach der nächsten Session siehst du hier deine Entwicklung.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            )
          else
            TrendLineChart(
              points: stats.trend,
              valueOf: (p) => _metric == _Metric.accuracy ? p.accuracy * 100 : p.points.toDouble(),
              formatValue: (v) => _metric == _Metric.accuracy ? '${v.round()}%' : '${v.round()}',
              lineColor: myBlue,
              dotColor: myOrange,
            ),
        ],
      ),
    );
  }

  Widget _metricToggle() {
    Widget segment(String label, _Metric value) {
      final selected = _metric == value;
      return GestureDetector(
        onTap: () => setState(() => _metric = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? myBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected ? myOrange : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('Genauigkeit', _Metric.accuracy),
          segment('Punkte', _Metric.points),
        ],
      ),
    );
  }

  Widget _categoryCard(ProgressStats stats) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nach Thema',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: myBlue),
          ),
          const SizedBox(height: 14),
          for (final c in stats.categoryBreakdown) ...[
            _categoryBar(c),
            if (c != stats.categoryBreakdown.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _categoryBar(CategoryBreakdown c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              c.category,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: myBlue),
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
            backgroundColor: myBlue.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(myBlue),
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

  Widget _recentSessionRow(SessionScore s) {
    final date = s.finishedAt.toLocal();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _gradeColor(s.grade).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              s.grade,
              style: TextStyle(fontWeight: FontWeight.bold, color: _gradeColor(s.grade)),
            ),
          ),
          const SizedBox(width: 12),
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
