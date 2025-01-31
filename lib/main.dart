import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'dart:async';
import 'models/robot_state.dart';
import 'services/tcp_client.dart';
import 'widgets/parameter_display.dart';
import 'widgets/position_control.dart';

void main() {
  // Set up logging
  Logger.root.level = Level.ALL; // Capture all log levels
  final mainLogger = Logger('Main');
  
  Logger.root.onRecord.listen((record) {
    final message = StringBuffer();
    message.write('${record.time}: ${record.level.name}: ${record.loggerName}: ${record.message}');
    
    if (record.error != null) {
      message.write('\nError: ${record.error}');
    }
    if (record.stackTrace != null) {
      message.write('\nStack trace:\n${record.stackTrace}');
    }
    
    debugPrint(message.toString());
  });

  mainLogger.info('Starting TwoBot Flutter application');
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => RobotState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TwoBot Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String mqttServerIp = '192.168.1.167'; // Update this to your robot's IP address
  late RobotState robotState;
  late TcpClient tcpClient;
  late MqttServerClient mqttClient;
  final _logger = Logger('DashboardScreen');
  bool _mqttConnected = false;

  @override
  void initState() {
    super.initState();
    robotState = context.read<RobotState>();
    tcpClient = TcpClient(robotState);
    _setupMqttClient();
    
    // Start periodic connection check
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && mqttClient.connectionStatus?.state != MqttConnectionState.connected) {
        setState(() {
          _mqttConnected = false;
        });
      }
    });
  }

  Timer? _connectionCheckTimer;

  Future<void> _setupMqttClient() async {
    mqttClient = MqttServerClient(mqttServerIp, 'two_bot_client_${DateTime.now().millisecondsSinceEpoch}');
    mqttClient.port = 1883;
    mqttClient.keepAlivePeriod = 20; // Reduced keep-alive period for faster detection
    mqttClient.logging(on: true);
    mqttClient.autoReconnect = true;
    mqttClient.resubscribeOnAutoReconnect = true;
    mqttClient.secure = false;
    mqttClient.onDisconnected = _onDisconnected;
    mqttClient.onConnected = _onConnected;
    mqttClient.onAutoReconnect = () {
      _logger.info('Auto reconnect triggered');
      setState(() {
        _mqttConnected = false;
      });
    };
    mqttClient.onAutoReconnected = () {
      _logger.info('Auto reconnected successfully');
      setState(() {
        _mqttConnected = true;
      });
    };
    mqttClient.pongCallback = () {
      _logger.fine('Ping response received');
      setState(() {
        _mqttConnected = true;
      });
    };

    // Set connection message with more detailed options
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('two_bot_client_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .withWillTopic('two_bot/status')
        .withWillMessage('offline');
    mqttClient.connectionMessage = connMessage;

    try {
      _logger.info('Attempting to connect to MQTT broker at $mqttServerIp:${mqttClient.port}');
      _logger.info('Connection settings: keepAlive=${mqttClient.keepAlivePeriod}, autoReconnect=${mqttClient.autoReconnect}');
      
      await mqttClient.connect();
      
      if (mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
        _logger.info('Successfully connected to MQTT broker');
        _logger.info('Client state: ${mqttClient.connectionStatus}');
        setState(() {
          _mqttConnected = true;
        });
      } else {
        _logger.severe('Failed to connect. Status: ${mqttClient.connectionStatus?.state}');
        setState(() {
          _mqttConnected = false;
        });
      }
    } catch (e) {
      _logger.severe('Failed to connect to MQTT broker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to robot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectClient() async {
    try {
      _logger.info('MQTT Connecting...');
      await mqttClient.connect();
      if (mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
        _logger.info('MQTT client connected successfully');
        // Subscribe to the data topic
        const topic = 'two_bot/data';
        mqttClient.subscribe(topic, MqttQos.atMostOnce);
        _logger.info('Subscribed to topic: $topic');
        
        // Set up message handler
        mqttClient.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
          final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
          
          try {
            final Map<String, dynamic> data = json.decode(payload);
            if (data.containsKey('state')) {
              robotState.updateFromJson(data['state']);
            } else {
              _logger.warning('Received message without state data: $payload');
            }
          } catch (e) {
            _logger.severe('Error parsing MQTT message: $e');
          }
        });
      } else {
        final status = mqttClient.connectionStatus;
        _logger.severe(
          'MQTT client connection failed - status is ${status?.state}. '
          'Return code: ${status?.returnCode}. '
          'Message: ${status?.returnCode?.toString() ?? "Unknown"}'
        );
        mqttClient.disconnect();
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to connect to MQTT broker: $e', e, stackTrace);
      mqttClient.disconnect();
    }
  }

  void _onDisconnected() {
    _logger.info('MQTT client disconnected');
    setState(() {
      _mqttConnected = false;
    });
    // Try to reconnect after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _logger.info('Attempting to reconnect to MQTT broker...');
        _connectClient();
      }
    });
  }

  void _onConnected() {
    _logger.info('MQTT client connected callback');
    setState(() {
      _mqttConnected = true;
    });
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    tcpClient.disconnect();
    mqttClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TwoBot Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  color: _mqttConnected ? Colors.green : Colors.red,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(_mqttConnected ? 'Connected' : 'Disconnected'),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: PositionControl(mqttClient: mqttClient),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ParameterDisplay(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
