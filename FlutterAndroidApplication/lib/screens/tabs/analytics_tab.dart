import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  List<dynamic> _metrics = [];
  Map<String, int> _prevMetrics = {};
  List<dynamic> _trends = [];
  bool _loading = true;
  String? _error;

  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int _secondsUntilRefresh = 10;
  DateTime? _lastUpdated;

  final Map<String, Map<String, String>> _metricMeta = {
    'adoptions_last_7d': {
      'label': 'Adoptions',
      'sub': 'Completed adoptions',
      'icon': '🐾',
    },
    'applications_last_7d': {
      'label': 'Applications',
      'sub': 'Submitted applications',
      'icon': '📋',
    },
    'pet_views_last_7d': {
      'label': 'Pet Views',
      'sub': 'Home page views',
      'icon': '👁️',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadData(showSpinner: true);

    // Setup periodic refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(showSpinner: false);
    });

    // Setup countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_secondsUntilRefresh <= 1) {
          _secondsUntilRefresh = 10;
        } else {
          _secondsUntilRefresh--;
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({required bool showSpinner}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final from = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();
      final to = DateTime.now().toUtc().toIso8601String();

      final metricsData = await ApiService.getMetrics();
      final trendsData = await ApiService.getTrends(from, to);

      // Track previous values for deltas
      final nextPrevMetrics = <String, int>{};
      for (var m in _metrics) {
        final name = m['metricName']?.toString() ?? '';
        final val = int.tryParse(m['value']?.toString() ?? '') ?? 0;
        nextPrevMetrics[name] = val;
      }

      setState(() {
        _prevMetrics = nextPrevMetrics;
        _metrics = metricsData;
        // Invert trends to show most recent first
        _trends = trendsData.reversed.toList();
        _lastUpdated = DateTime.now();
        _secondsUntilRefresh = 10;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (showSpinner) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
    final name = metric['metricName']?.toString() ?? '';
    final val = int.tryParse(metric['value']?.toString() ?? '') ?? 0;
    final meta = _metricMeta[name] ?? {'label': name, 'sub': '', 'icon': '📊'};

    final prevVal = _prevMetrics[name];
    final delta = prevVal != null && val != prevVal ? val - prevVal : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(meta['icon'] ?? '📊', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  '$val',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                ),
                const SizedBox(height: 2),
                Text(
                  meta['label'] ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  meta['sub'] ?? '',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (delta != 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: delta > 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${delta > 0 ? "+" : ""}$delta',
                    style: TextStyle(
                      color: delta > 0 ? Colors.green[700] : Colors.red[700],
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadData(showSpinner: true),
        color: const Color(0xFFB45309),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Performance Metrics',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                      if (_lastUpdated != null)
                        Text(
                          'Updated ${_lastUpdated!.hour.toString().padLeft(2, "0")}:${_lastUpdated!.minute.toString().padLeft(2, "0")}:${_lastUpdated!.second.toString().padLeft(2, "0")} • auto-refresh in ${_secondsUntilRefresh}s',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _loadData(showSpinner: true),
                    color: const Color(0xFFB45309),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: Color(0xFFB45309)),
                  ),
                )
              else ...[
                // Metrics grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _metrics.length,
                  itemBuilder: (ctx, idx) => _buildMetricCard(_metrics[idx]),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Historical Trends (30 Days)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 8),

                // Trends Table Card
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFFEF3C7)),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Date',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            '🐾 Adoptions',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            '📋 Applications',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 12),
                          ),
                        ),
                        DataColumn(
                          numeric: true,
                          label: Text(
                            '👁️ Views',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 12),
                          ),
                        ),
                      ],
                      rows: _trends.map((t) {
                        final dateStr = t['date'] as String? ?? '';
                        String displayDate = dateStr;
                        if (dateStr.isNotEmpty) {
                          try {
                            final parsedDate = DateTime.parse(dateStr);
                            displayDate = '${parsedDate.month}/${parsedDate.day}';
                          } catch (_) {}
                        }

                        return DataRow(
                          cells: [
                            DataCell(Text(displayDate, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text('${t['adoptions'] ?? 0}', style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold))),
                            DataCell(Text('${t['applications'] ?? 0}')),
                            DataCell(Text('${t['views'] ?? 0}', style: const TextStyle(color: Colors.grey))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
