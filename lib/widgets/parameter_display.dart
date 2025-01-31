import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
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
                _buildParameterTile(context, 'Kp', robotState.kp),
                _buildParameterTile(context, 'Ki', robotState.ki),
                _buildParameterTile(context, 'Kd', robotState.kd),
                _buildParameterTile(context, 'Kp2', robotState.kp2),
                _buildParameterTile(context, 'Ki2', robotState.ki2),
                _buildParameterTile(context, 'Kd2', robotState.kd2),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildParameterTile(BuildContext context, String label, double value) {
    // Only make PID parameters clickable
    final bool isClickable = ['Kp', 'Ki', 'Kd', 'Kp2', 'Ki2', 'Kd2'].contains(label);

    Widget content = Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isClickable ? Theme.of(context).primaryColor : null,
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

    if (isClickable) {
      return InkWell(
        onTap: () => _showParameterDialog(context, label, value),
        child: content,
      );
    }

    return content;
  }

  Future<void> _showParameterDialog(BuildContext context, String label, double currentValue) async {
    final TextEditingController controller = TextEditingController(
      text: currentValue.toString(),
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Set $label'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Enter new value',
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newValue = double.tryParse(controller.text);
                if (newValue != null) {
                  _updateParameter(context, label, newValue);
                }
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _updateParameter(BuildContext context, String label, double value) {
    final robotState = context.read<RobotState>();
    robotState.updateParameter(label, value);

    // Send the update via MQTT
    if (mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      final message = {
        'command': 'update_parameter',
        'parameter': label,
        'value': value,
      };
      builder.addString(jsonEncode(message));
      mqttClient.publishMessage(
        'two_bot/control_topic',
        MqttQos.atMostOnce,
        builder.payload!,
      );
    }
  }
}
