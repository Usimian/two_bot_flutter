import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/robot_state.dart';

class TcpClient {
  static const String serverIP = "192.168.50.50";
  static const int port = 5000;

  Socket? _socket;
  final RobotState robotState;
  bool isConnected = false;
  late MqttClient mqttClient;
  final _logger = Logger('TcpClient');

  TcpClient(this.robotState);

  Future<void> connect() async {
    try {
      _socket = await Socket.connect(serverIP, port);
      isConnected = true;
      _logger.info('Connected to server $serverIP:$port');

      _socket!.listen(
        (List<int> data) {
          final String message = utf8.decode(data);
          try {
            final Map<String, dynamic> jsonData = json.decode(message);
            robotState.updateFromJson(jsonData);
          } catch (e) {
            _logger.severe('Error parsing data: $e');
          }
        },
        onError: (error) {
          _logger.severe('Error: $error');
          disconnect();
        },
        onDone: () {
          _logger.info('Server disconnected');
          disconnect();
        },
      );
    } catch (e) {
      _logger.severe('Failed to connect: $e');
      isConnected = false;
    }
  }

  Future<void> connectMqtt(String broker, String clientId) async {
    mqttClient = MqttClient(broker, clientId);
    mqttClient.port = 1883; // Default MQTT port

    try {
      await mqttClient.connect();
      _logger.info('Connected to MQTT broker');
    } catch (e) {
      _logger.severe('Connection failed: $e');
    }
  }

  Future<void> subscribe(String topic) async {
    mqttClient.subscribe(topic, MqttQos.atMostOnce);
    _logger.info('Subscribed to $topic');
  }

  Future<void> publish(String message) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    mqttClient.publishMessage('two_bot/control', MqttQos.atMostOnce, builder.payload!);
    _logger.info('Published message to two_bot/control');
  }

  void sendPosition(int position) {
    if (mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
      final message = json.encode({'position': position});
      publish(message);
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    isConnected = false;
  }
}
