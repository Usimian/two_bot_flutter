import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/robot_state.dart';

class ParameterDisplay extends StatelessWidget {
  const ParameterDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotState>(
      builder: (context, robotState, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Adjust grid columns based on width
            int crossAxisCount = constraints.maxWidth < 600 ? 2 : 3;
            
            return GridView.count(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 5.0,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildParameterTile('Rp', robotState.rp),
                _buildParameterTile('Ri', robotState.ri),
                _buildParameterTile('Rd', robotState.rd),
                _buildParameterTile('Kp', robotState.kp),
                _buildParameterTile('Ki', robotState.ki),
                _buildParameterTile('Kd', robotState.kd),
                _buildParameterTile('Kp2', robotState.kp2),
                _buildParameterTile('Ki2', robotState.ki2),
                _buildParameterTile('Kd2', robotState.kd2),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildParameterTile(String label, double value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.toStringAsFixed(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
