import 'dart:async';

import 'package:flutter/services.dart';

const EventChannel _sensorEventChannel =
    EventChannel('plugins.aeyrium.com/sensor');

class SensorEvent {
  /// Pitch from the device in radians
  /// A pitch is a rotation around a lateral (X) axis that passes through the device from side to side
  final double pitch;

  ///Roll value from the device in radians
  ///A roll is a rotation around a longitudinal (Y) axis that passes through the device from its top to bottom
  final double roll;

  final double yaw;

  SensorEvent(
    this.pitch,
    this.roll,
    this.yaw,
  );

  @override
  String toString() => '[Event: (pitch: $pitch, roll: $roll)]';
}

class AeyriumSensor {
  static final Stream sensorEvents = _sensorEventChannel
      .receiveBroadcastStream()
      .map((dynamic event) => _listToSensorEvent(event.cast()));

  AeyriumSensor._();

  /// A broadcast stream of events from the device rotation sensor. static Stream get sensorEvents => sensorEvents;
  static SensorEvent _listToSensorEvent(List list) {
    return SensorEvent(list[0], list[1], list[2]);
  }
}
