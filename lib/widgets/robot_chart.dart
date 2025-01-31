import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class RobotChart extends StatefulWidget {
  const RobotChart({super.key});

  @override
  State<RobotChart> createState() => _RobotChartState();
}

class _RobotChartState extends State<RobotChart> {
  final List<FlSpot> speedPoints = [];
  final List<FlSpot> positionPoints = [];
  final int maxDataPoints = 100;
  int currentX = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with some dummy data
    for (int i = 0; i < maxDataPoints; i++) {
      speedPoints.add(FlSpot(i.toDouble(), math.sin(i / 4) * 10));
      positionPoints.add(FlSpot(i.toDouble(), math.cos(i / 4) * 20));
    }
  }

  void updateData() {
    if (!mounted) return;

    setState(() {
      currentX++;
      if (speedPoints.length >= maxDataPoints) {
        speedPoints.removeAt(0);
        positionPoints.removeAt(0);
      }

      // Add new random points (replace this with actual data)
      final random = math.Random();
      speedPoints.add(FlSpot(currentX.toDouble(), random.nextDouble() * 20 - 10));
      positionPoints.add(FlSpot(currentX.toDouble(), random.nextDouble() * 40 - 20));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true),
            titlesData: const FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 22),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: speedPoints,
                color: Colors.red,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: positionPoints,
                color: Colors.green,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
            minX: (currentX - maxDataPoints).toDouble(),
            maxX: currentX.toDouble(),
            minY: -100,
            maxY: 100,
          ),
        ),
      ),
    );
  }
}
