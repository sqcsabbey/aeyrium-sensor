import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _sensorMethodChannel =
    MethodChannel('plugins.aeyrium.com/sensor_method');
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
  static Stream<SensorEvent>? _sensorEvents;
  static bool _isStarted = false;

  AeyriumSensor._();

  /// A broadcast stream of events from the device rotation sensor.
  static Stream<SensorEvent> get sensorEvents {
    var e = _sensorEvents;
    if (e == null) {
      // print('AeyriumSensor: Creating new sensor event stream');
      e = _sensorEvents = _sensorEventChannel
          .receiveBroadcastStream()
          .map((dynamic event) {
            if (event == null) {
              // print('AeyriumSensor: Received null event from platform');
              throw Exception('Null event received from platform');
            }
            // print('AeyriumSensor: Received event data: $event');
            return _listToSensorEvent(event.cast<double>());
          })
          .handleError((error) {
            // print('AeyriumSensor: Error in event stream: $error');
            throw error;
          });
    } else {
      // print('AeyriumSensor: Returning existing sensor event stream');
    }
    return e;
  }

  /// Starts the sensor data collection.
  static Future<void> start() async {
    if (!_isStarted) {
      try {
        await _sensorMethodChannel.invokeMethod('start');
        _isStarted = true;
      } catch (e) {
        // print('Error starting sensor: $e');
        rethrow;
      }
    }
  }

  /// Stops the sensor data collection to save battery.
  static Future<void> stop() async {
    if (_isStarted) {
      await _sensorMethodChannel.invokeMethod('stop');
      _isStarted = false;
      _sensorEvents = null;
    }
  }

  /// Returns true if the sensor is currently started.
  static bool get isStarted => _isStarted;

  /// Checks if the sensor is available on the device.
  static Future<bool> checkSensorAvailability() async {
    try {
      final bool isAvailable = await _sensorMethodChannel.invokeMethod('checkAvailability') ?? false;
      // print('AeyriumSensor: Sensor availability check result: $isAvailable');
      return isAvailable;
    } catch (e) {
      // print('AeyriumSensor: Error checking sensor availability: $e');
      return false;
    }
  }

  static SensorEvent _listToSensorEvent(List<double> list) {
    return SensorEvent(list[0], list[1], list[2]);
  }
}
