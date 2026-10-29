import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // A function we can call to manually trigger a UI rebuild
  Future<void> _handleRefresh() async {
    setState(() {}); // This forces the build() method to run again
  }

  @override
  Widget build(BuildContext context) {
    // 1. Grab the user ID right here in the build method
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown_user';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Wellness Trends',
          style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      // 2. Add Pull-to-Refresh capability
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.indigo,
        // 3. Put the API call directly in the future parameter! 
        // Now it runs every time the tab is opened or refreshed.
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: ApiService.fetchMoodHistory(userId),
          builder: (context, snapshot) {
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.indigo));
            }

            String avgScoreDisplay = "0/100";
            String alertsDisplay = "0 Alerts";
            List<FlSpot> realSpots = [];
            List<Map<String, dynamic>> history = [];
            bool hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
// --- THE MATH ENGINE ---
          if (hasData) {
            history = snapshot.data!;
            double totalScore = 0;
            int alertCount = 0;


            for (int i = 0; i < history.length; i++) {
              // 1. Use 'num' to safely handle both int and double from JSON
              num score = history[i]['score'] ?? 0;
              totalScore += score;

              // 2. Count how many times the score triggered the CBT threshold (< 50)
              if (score < 50) {
                alertCount++;
              }

              realSpots.add(FlSpot(i.toDouble(), score.toDouble()));
            }

            // Calculate average and format it beautifully
            int average = (totalScore / history.length).round();
            avgScoreDisplay = "$average/100";
            alertsDisplay = alertCount == 1 ? "1 Alert" : "$alertCount Alerts";
            
          }
            // Must use SingleChildScrollView with AlwaysScrollableScrollPhysics 
            // for RefreshIndicator to work properly!
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard('7-Day Avg', avgScoreDisplay, Icons.trending_up, Colors.teal)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSummaryCard('Insights', alertsDisplay, Icons.insights, Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Your Weekly Progress',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2D3748)),
                  ),
                  const SizedBox(height: 20),
                  
                  if (!hasData)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(child: Text('No AI logs yet. Go write in your journal!', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    Container(
                      height: 300,
                      padding: const EdgeInsets.only(right: 20, left: 10, top: 20, bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true, drawVerticalLine: false, horizontalInterval: 20,
                            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index >= 0 && index < history.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(history[index]['date'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true, reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toInt()}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12));
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: (history.length - 1 < 6) ? 6 : (history.length - 1).toDouble(),
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: realSpots, isCurved: true, color: Colors.indigo,
                              barWidth: 4, isStrokeCapRound: true, dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: Colors.indigo.withOpacity(0.15)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }
}