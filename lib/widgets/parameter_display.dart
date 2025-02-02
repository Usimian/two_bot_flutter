import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/robot_state.dart';

class ParameterDisplay extends StatelessWidget {
  final MqttServerClient mqttClient;

  const ParameterDisplay({
    super.key,
    required this.mqttClient,
  });

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
                _buildParameterTile(context, 'Rp', robotState.rp),
                _buildParameterTile(context, 'Ri', robotState.ri),
                _buildParameterTile(context, 'Rd', robotState.rd),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildParameterTile(BuildContext context, String label, double value) {
    // Only show Rp, Ri, Rd parameters
    if (['Kp', 'Ki', 'Kd', 'Kp2', 'Ki2', 'Kd2'].contains(label)) {
      return const SizedBox.shrink(); // Don't show PID parameters
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            )),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
