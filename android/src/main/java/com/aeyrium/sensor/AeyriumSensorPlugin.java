package com.aeyrium.sensor;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodCall;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.view.Surface;
import android.view.WindowManager;
import android.view.Display;
import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;
// import android.util.Log;

/** AeyriumSensorPlugin */
public class AeyriumSensorPlugin implements FlutterPlugin, EventChannel.StreamHandler, ActivityAware, MethodCallHandler {
  // private static final String TAG = "AeyriumSensor";
  
  private static final String SENSOR_CHANNEL_NAME =
          "plugins.aeyrium.com/sensor";
  private static final String METHOD_CHANNEL_NAME =
          "plugins.aeyrium.com/sensor_method";
  private static final int SENSOR_DELAY_MICROS = 1000 * 1000;//16 * 1000;
  private WindowManager mWindowManager;
  private SensorEventListener sensorEventListener;
  private SensorManager sensorManager;
  private Sensor sensor;
  private int mLastAccuracy;
  private EventChannel.EventSink eventSink;
  private boolean isStarted = false;
  BinaryMessenger binaryMessenger;


  public AeyriumSensorPlugin(){}

  private AeyriumSensorPlugin(Context context, int sensorType, Activity activity) {
    // Log.d(TAG, "Initializing AeyriumSensorPlugin");
    mWindowManager = activity.getWindow().getWindowManager();
    sensorManager = (SensorManager) context.getSystemService(context.SENSOR_SERVICE);
    sensor = sensorManager.getDefaultSensor(sensorType);
    
    // if (sensor == null) {
    //   Log.e(TAG, "ERROR: Rotation vector sensor not available on this device!");
    // } else {
    //   Log.d(TAG, "Rotation vector sensor found: " + sensor.getName());
    // }
  }

  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    // Log.d(TAG, "onListen called, isStarted: " + isStarted);
    eventSink = events;
    sensorEventListener = createSensorEventListener(events);
    if (isStarted) {
      // Log.d(TAG, "Sensor already started, registering listener immediately");
      if (sensor != null && sensorManager != null) {
        boolean registered = sensorManager.registerListener(sensorEventListener, sensor, sensorManager.SENSOR_DELAY_UI);
        // Log.d(TAG, "Sensor listener registration result: " + registered);
      } else {
        // Log.e(TAG, "ERROR: Cannot register listener - sensor or sensorManager is null");
      }
    } else {
      // Log.d(TAG, "Sensor not started yet, waiting for start command");
    }
  }

  @Override
  public void onCancel(Object arguments) {
    // Log.d(TAG, "onCancel called, unregistering sensor listener");
    if (sensorManager != null && sensorEventListener != null){
        sensorManager.unregisterListener(sensorEventListener);
    }
    eventSink = null;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "start":
        // Log.d(TAG, "Received start command");
        startSensors();
        result.success(null);
        break;
      case "stop":
        // Log.d(TAG, "Received stop command");
        stopSensors();
        result.success(null);
        break;
      case "checkAvailability":
        // Log.d(TAG, "Checking sensor availability");
        boolean isAvailable = sensor != null;
        // Log.d(TAG, "Sensor availability: " + isAvailable);
        result.success(isAvailable);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private void startSensors() {
    // Log.d(TAG, "startSensors called, current isStarted: " + isStarted);
    if (!isStarted) {
      if (sensorManager == null) {
        // Log.e(TAG, "ERROR: sensorManager is null");
        return;
      }
      if (sensor == null) {
        // Log.e(TAG, "ERROR: sensor is null - rotation vector sensor not available");
        return;
      }
      
      isStarted = true;
      // Log.d(TAG, "Set isStarted to true");
      
      if (sensorEventListener != null && eventSink != null) {
        boolean registered = sensorManager.registerListener(sensorEventListener, sensor, sensorManager.SENSOR_DELAY_UI);
        // Log.d(TAG, "Immediately registered sensor listener, result: " + registered);
      } else {
        // Log.d(TAG, "Will register listener when onListen is called (listener: " + 
        //            (sensorEventListener != null ? "exists" : "null") + 
        //            ", eventSink: " + (eventSink != null ? "exists" : "null") + ")");
      }
    } else {
      // Log.d(TAG, "Sensors already started");
    }
  }

  private void stopSensors() {
    // Log.d(TAG, "stopSensors called, current isStarted: " + isStarted);
    if (isStarted && sensorManager != null && sensorEventListener != null) {
      sensorManager.unregisterListener(sensorEventListener);
      isStarted = false;
      // Log.d(TAG, "Stopped sensors and set isStarted to false");
    }
  }

  SensorEventListener createSensorEventListener(final EventChannel.EventSink events) {
    return new SensorEventListener() {
      @Override
      public void onAccuracyChanged(Sensor sensor, int accuracy) {
        if (mLastAccuracy != accuracy) {
          mLastAccuracy = accuracy;
          // Log.d(TAG, "Sensor accuracy changed to: " + accuracy);
        }
      }

      @Override
      public void onSensorChanged(SensorEvent event) {
        if (mLastAccuracy == SensorManager.SENSOR_STATUS_UNRELIABLE) {
          // Log.w(TAG, "Sensor data unreliable, skipping update");
          return;
        }

        updateOrientation(event.values, events);
      }
    };
  }
  
  private void updateOrientation(float[] rotationVector, EventChannel.EventSink events) {
    float[] rotationMatrix = new float[9];
    SensorManager.getRotationMatrixFromVector(rotationMatrix, rotationVector);

    final int worldAxisForDeviceAxisX;
    final int worldAxisForDeviceAxisY;

    // Remap the axes as if the device screen was the instrument panel,
    // and adjust the rotation matrix for the device orientation.
    Display display = mWindowManager.getDefaultDisplay();
    switch (display.getRotation()) {
      case Surface.ROTATION_0:
      default:
        worldAxisForDeviceAxisX = SensorManager.AXIS_X;
        worldAxisForDeviceAxisY = SensorManager.AXIS_Z;
        break;
      case Surface.ROTATION_90:
        worldAxisForDeviceAxisX = SensorManager.AXIS_Z;
        worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_X;
        break;
      case Surface.ROTATION_180:
        worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_X;
        worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_Z;
        break;
      case Surface.ROTATION_270:
        worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_Z;
        worldAxisForDeviceAxisY = SensorManager.AXIS_X;
        break;
    }

    
    float[] adjustedRotationMatrix = new float[9];
    SensorManager.remapCoordinateSystem(rotationMatrix, worldAxisForDeviceAxisX,
            worldAxisForDeviceAxisY, adjustedRotationMatrix);

    // Transform rotation matrix into azimuth/pitch/roll
    float[] orientation = new float[3];
    SensorManager.getOrientation(adjustedRotationMatrix, orientation);

    double yaw = orientation[0];
    double pitch = - orientation[1];
    double roll = - orientation[2];
    double[] sensorValues = new double[3];
    sensorValues[0] = pitch;
    sensorValues[1] = roll;
    sensorValues[2] = yaw;
    events.success(sensorValues);
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    binaryMessenger = binding.getBinaryMessenger();
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {

  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    final EventChannel sensorChannel =
            new EventChannel(binaryMessenger, SENSOR_CHANNEL_NAME);
    final MethodChannel methodChannel = 
            new MethodChannel(binaryMessenger, METHOD_CHANNEL_NAME);
    
    AeyriumSensorPlugin plugin = new AeyriumSensorPlugin(binding.getActivity().getApplicationContext(), Sensor.TYPE_ROTATION_VECTOR, binding.getActivity());
    sensorChannel.setStreamHandler(plugin);
    methodChannel.setMethodCallHandler(plugin);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {

  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {

  }

  @Override
  public void onDetachedFromActivity() {

  }
}