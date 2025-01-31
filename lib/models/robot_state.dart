import 'package:flutter/foundation.dart';

class RobotState extends ChangeNotifier {
  double rp = 0.0;
  double ri = 0.0;
  double rd = 0.0;
  double kp = 0.0;
  double ki = 0.0;
  double kd = 0.0;
  double kp2 = 0.0;
  double ki2 = 0.0;
  double kd2 = 0.0;
  double pos = 0.0;
  double vb = 0.0;
  double targetPosition = 0.0;

  void updateFromJson(Map<String, dynamic> json) {
    rp = json['Rp']?.toDouble() ?? 0.0;
    ri = json['Ri']?.toDouble() ?? 0.0;
    rd = json['Rd']?.toDouble() ?? 0.0;
    kp = json['Kp']?.toDouble() ?? 0.0;
    ki = json['Ki']?.toDouble() ?? 0.0;
    kd = json['Kd']?.toDouble() ?? 0.0;
    kp2 = json['Kp2']?.toDouble() ?? 0.0;
    ki2 = json['Ki2']?.toDouble() ?? 0.0;
    kd2 = json['Kd2']?.toDouble() ?? 0.0;
    pos = json['Pos']?.toDouble() ?? 0.0;
    vb = json['Vb']?.toDouble() ?? 0.0;
    notifyListeners();
  }

  void setTargetPosition(double newPosition) {
    targetPosition = newPosition;
    notifyListeners();
  }
}
