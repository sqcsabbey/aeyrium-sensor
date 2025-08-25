import 'dart:async';

import 'package:aeyrium_sensor/aeyrium_sensor.dart';
import 'package:flutter/material.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _data = "";
  bool _isStarted = false;

  StreamSubscription<dynamic>? _streamSubscriptions;

  @override
  void initState() {
    super.initState();
    _checkSensorAvailability();
  }

  void _checkSensorAvailability() async {
    final isAvailable = await AeyriumSensor.checkSensorAvailability();
    if (!isAvailable) {
      setState(() {
        _data = "Sensor not available on this device";
      });
    }
  }

  void _startSensors() async {
    // print('Starting sensors...');
    
    // Check availability first
    final isAvailable = await AeyriumSensor.checkSensorAvailability();
    if (!isAvailable) {
      // print('Sensor not available on this device');
      setState(() {
        _data = "Error: Sensor not available";
      });
      return;
    }
    
    try {
      await AeyriumSensor.start();
      // print('Start command sent, setting up event listener...');
      
      _streamSubscriptions = AeyriumSensor.sensorEvents.listen(
        (event) {
          // print('Received sensor event: pitch=${event.pitch}, roll=${event.roll}, yaw=${event.yaw}');
          setState(() {
            _data = "Pitch ${event.pitch} , Roll ${event.roll}";
          });
        },
        onError: (error) {
          // print('Error in sensor stream: $error');
          setState(() {
            _data = "Error: Stream error - $error";
          });
        },
      );
      
      setState(() {
        _isStarted = true;
        _data = "Sensor started, waiting for data...";
      });
      // print('Sensor started successfully');
    } catch (e) {
      // print('Failed to start sensor: $e');
      setState(() {
        _data = "Error: Failed to start sensor - $e";
      });
    }
  }

  void _stopSensors() async {
    await AeyriumSensor.stop();
    _streamSubscriptions?.cancel();
    _streamSubscriptions = null;
    setState(() {
      _isStarted = false;
      _data = "Sensor stopped";
    });
  }

  @override
  void dispose() {
    _streamSubscriptions?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: new Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                new Text('Device : $_data'),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isStarted ? null : _startSensors,
                      child: Text('Start Sensor'),
                    ),
                    ElevatedButton(
                      onPressed: _isStarted ? _stopSensors : null,
                      child: Text('Stop Sensor'),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text('Status: ${_isStarted ? "Running" : "Stopped"}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
