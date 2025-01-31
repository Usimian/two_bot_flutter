import 'package:flutter_test/flutter_test.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  test('MQTT broker connection test', () async {
    final client = MqttServerClient('192.168.1.167', 'test_client');
    client.port = 1883;
    client.keepAlivePeriod = 60;
    client.logging(on: true);

    try {
      await client.connect();
      print('*****SUCCESSFULLY CONNECTED TO MQTT BROKER AT ${client.server}:${client.port}*****');
      expect(client.connectionStatus?.state, MqttConnectionState.connected,
          reason: 'Failed to connect to MQTT broker');
    } catch (e) {
      fail('Could not connect to MQTT broker: $e');
    } finally {
      client.disconnect();
    }
  });
}
