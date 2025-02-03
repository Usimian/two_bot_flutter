import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'dart:convert'; // Import dart:convert for json.decode
import 'models/robot_state.dart';
import 'services/tcp_client.dart';
import 'widgets/parameter_display.dart';
import 'widgets/position_control.dart';

// MQTT Topics
const String kMqttTopicStatusRequest = 'two_bot/status_request';
const String kMqttTopicStatusResponse = 'two_bot/status_response';
const String kMqttTopicControlRequest = 'two_bot/control_request';

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
  static const String _mqttServerIp = '192.168.1.167'; // Update this to your robot's IP address
  late RobotState _robotState;
  late TcpClient _tcpClient;
  late MqttServerClient _mqttClient;
  final _logger = Logger('DashboardScreen');
  bool _isMqttConnected = false;
  bool _isRobotRunning = false;
  Timer? _connectionCheckTimer;
  Timer? _statusCheckTimer;
  Timer? _statusTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _robotState = context.read<RobotState>();
    _tcpClient = TcpClient(_robotState);
    _setupMqttClient();
    
    // Start periodic connection check
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _mqttClient.connectionStatus?.state != MqttConnectionState.connected) {
        setState(() {
          _isMqttConnected = false;
        });
      }
    });

    // Start periodic status check
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _isMqttConnected) {
        _requestRobotStatus();
      }
    });
  }

  void _requestRobotStatus() {
    final builder = MqttClientPayloadBuilder();
    builder.addString('status');
    _mqttClient.publishMessage(
      kMqttTopicStatusRequest,
      MqttQos.atMostOnce,
      builder.payload!,
    );

    // Cancel any existing timeout timer
    _statusTimeoutTimer?.cancel();
    
    // Start a new timeout timer
    _statusTimeoutTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isRobotRunning = false;  // Set to stopped if no response received
        });
        // Set battery voltage to 0 when no response
        _robotState.updateFromJson({'Vb': 0.0});
      }
    });
  }

  Future<void> _setupMqttClient() async {
    _mqttClient = MqttServerClient(_mqttServerIp, 'two_bot_client_${DateTime.now().millisecondsSinceEpoch}');
    _mqttClient.port = 1883;
    _mqttClient.keepAlivePeriod = 20; // Reduced keep-alive period for faster detection
    _mqttClient.logging(on: true);
    _mqttClient.autoReconnect = true;
    _mqttClient.resubscribeOnAutoReconnect = true;
    _mqttClient.secure = false;
    _mqttClient.onDisconnected = _onDisconnected;
    _mqttClient.onConnected = _onConnected;
    _mqttClient.onAutoReconnect = () {
      _logger.info('Auto reconnect triggered');
      setState(() {
        _isMqttConnected = false;
      });
    };
    _mqttClient.onAutoReconnected = () {
      _logger.info('Auto reconnected successfully');
      setState(() {
        _isMqttConnected = true;
      });
    };
    _mqttClient.pongCallback = () {
      _logger.fine('Ping response received');
      setState(() {
        _isMqttConnected = true;
      });
    };

    // Set connection message with more detailed options
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('two_bot_client_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .withWillTopic(kMqttTopicStatusRequest)
        .withWillMessage('offline');
    _mqttClient.connectionMessage = connMessage;

    try {
      _logger.info('Attempting to connect to MQTT broker at $_mqttServerIp:${_mqttClient.port}');
      _logger.info('Connection settings: keepAlive=${_mqttClient.keepAlivePeriod}, autoReconnect=${_mqttClient.autoReconnect}');
      
      await _mqttClient.connect();
      
      if (_mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
        _logger.info('Successfully connected to MQTT broker');
        _logger.info('Client state: ${_mqttClient.connectionStatus}');
        setState(() {
          _isMqttConnected = true;
        });
      } else {
        _logger.severe('Failed to connect. Status: ${_mqttClient.connectionStatus?.state}');
        setState(() {
          _isMqttConnected = false;
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
      await _mqttClient.connect();
      if (_mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
        _logger.info('MQTT client connected successfully');
        setState(() {
          _isMqttConnected = true;
        });
      }
    } catch (e) {
      _logger.severe('Error connecting to MQTT broker: $e');
      setState(() {
        _isMqttConnected = false;
      });
    }
  }

  void _onDisconnected() {
    _logger.info('MQTT client disconnected');
    setState(() {
      _isMqttConnected = false;
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
      _isMqttConnected = true;
    });

    // Subscribe to response topic
    _mqttClient.subscribe(kMqttTopicStatusResponse, MqttQos.atMostOnce);

    // Set up message handler for status updates
    _mqttClient.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
      
      if (c[0].topic == kMqttTopicStatusResponse) {
        // Cancel the timeout timer since we received a response
        _statusTimeoutTimer?.cancel();
        
        try {
          final double value = double.parse(payload);
          final bool isRunning = value > 0;
          final double batteryVoltage = isRunning ? value : 0.0;
          
          // Update robot state with battery voltage
          _robotState.updateFromJson({'Vb': batteryVoltage});
          
          setState(() {
            _isRobotRunning = isRunning;
          });
        } catch (e) {
          _logger.warning('Failed to parse status response: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _statusCheckTimer?.cancel();
    _statusTimeoutTimer?.cancel();
    _tcpClient.disconnect();
    _mqttClient.disconnect();
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
                  color: _isMqttConnected ? const Color.fromARGB(255, 0, 255, 8) : const Color.fromARGB(255, 255, 17, 0),
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(_isMqttConnected ? 'Connected' : 'Disconnected'),
                const SizedBox(width: 16),
                Icon(
                  Icons.circle,
                  color: _isRobotRunning ? const Color.fromARGB(255, 0, 255, 8) : const Color.fromARGB(255, 255, 0, 0),
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(_isRobotRunning ? 'Running' : 'Stopped'),
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
            child: PositionControl(mqttClient: _mqttClient),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ParameterDisplay(mqttClient: _mqttClient),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
