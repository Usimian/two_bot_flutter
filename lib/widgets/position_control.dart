import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/robot_state.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dart:convert';
import 'package:logging/logging.dart';

class PositionControl extends StatelessWidget {
  final MqttClient mqttClient;
  final _logger = Logger('PositionControl');

  PositionControl({super.key, required this.mqttClient});

  @override
  Widget build(BuildContext context) {
    return Consumer<RobotState>(
      builder: (context, robotState, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            bool isNarrow = constraints.maxWidth < 600;
            
            Widget controlsRow = Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Slider(
                    min: -500,
                    max: 500,
                    divisions: 1000,
                    value: robotState.targetPosition,
                    onChanged: (value) {
                      final roundedValue = value.round();
                      robotState.setTargetPosition(roundedValue.toDouble());
                      if (mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
                        final builder = MqttClientPayloadBuilder();
                        final message = {
                          'command': 'set_position',
                          'position': roundedValue,
                          'timestamp': DateTime.now().toIso8601String()
                        };
                        builder.addString(jsonEncode(message));
                        mqttClient.publishMessage('two_bot/control_topic', MqttQos.atMostOnce, builder.payload!);
                        _logger.fine('Published position update: $roundedValue');
                      } else {
                        _logger.warning('Cannot publish position: MQTT client not connected');
                      }
                    },
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Target: ${robotState.targetPosition.round()}mm',
                    ),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Current: ${robotState.pos.round()}mm',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    robotState.setTargetPosition(0);
                    if (mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
                      final builder = MqttClientPayloadBuilder();
                      final message = {
                        'command': 'set_position',
                        'position': 0,
                        'timestamp': DateTime.now().toIso8601String()
                      };
                      builder.addString(jsonEncode(message));
                      mqttClient.publishMessage('two_bot/control_topic', MqttQos.atMostOnce, builder.payload!);
                      _logger.fine('Published reset position command');
                    } else {
                      _logger.warning('Cannot reset position: MQTT client not connected');
                    }
                  },
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Zero Position'),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: robotState.vb < 10.0 ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Battery: ${robotState.vb.toStringAsFixed(2)}V',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  controlsRow,
                ],
              );
            }

            return controlsRow;
          },
        );
      },
    );
  }
}
