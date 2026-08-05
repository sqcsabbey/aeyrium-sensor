#import "AeyriumSensorPlugin.h"
#import <CoreMotion/CoreMotion.h>
#import <GLKit/GLKit.h>

@implementation AeyriumSensorPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FLTSensorStreamHandler* sensorStreamHandler =
      [[FLTSensorStreamHandler alloc] init];
  FlutterEventChannel* sensorChannel =
      [FlutterEventChannel eventChannelWithName:@"plugins.aeyrium.com/sensor"
                                binaryMessenger:[registrar messenger]];
  [sensorChannel setStreamHandler:sensorStreamHandler];
  
  FlutterMethodChannel* methodChannel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.aeyrium.com/sensor_method"
                                   binaryMessenger:[registrar messenger]];
  [methodChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
    if ([@"start" isEqualToString:call.method]) {
      // NSLog(@"AeyriumSensor: Received start command");
      [sensorStreamHandler startSensors];
      result(nil);
    } else if ([@"stop" isEqualToString:call.method]) {
      // NSLog(@"AeyriumSensor: Received stop command");
      [sensorStreamHandler stopSensors];
      result(nil);
    } else if ([@"checkAvailability" isEqualToString:call.method]) {
      // NSLog(@"AeyriumSensor: Checking sensor availability");
      CMMotionManager* tempManager = [[CMMotionManager alloc] init];
      BOOL isAvailable = [tempManager isDeviceMotionAvailable];
      // NSLog(@"AeyriumSensor: Device motion available: %@", isAvailable ? @"YES" : @"NO");
      result(@(isAvailable));
    } else {
      result(FlutterMethodNotImplemented);
    }
  }];
}

@end

CMMotionManager* _motionManager;

void _initMotionManager() {
  if (!_motionManager) {
    // NSLog(@"AeyriumSensor: Initializing motion manager");
    _motionManager = [[CMMotionManager alloc] init];
    _motionManager.deviceMotionUpdateInterval = 0.03;
    
    // if ([_motionManager isDeviceMotionAvailable]) {
    //   NSLog(@"AeyriumSensor: Device motion is available");
    // } else {
    //   NSLog(@"AeyriumSensor: ERROR - Device motion is NOT available!");
    // }
  } else {
    // NSLog(@"AeyriumSensor: Motion manager already initialized");
  }
}

static void sendData(Float64 pitch, Float64 roll,Float64 yaw, FlutterEventSink sink) {
  NSMutableData* event = [NSMutableData dataWithCapacity:2 * sizeof(Float64)];
  [event appendBytes:&pitch length:sizeof(Float64)];
  [event appendBytes:&roll length:sizeof(Float64)];
  [event appendBytes:&yaw length:sizeof(Float64)];
  sink([FlutterStandardTypedData typedDataWithFloat64:event]);
}


@implementation FLTSensorStreamHandler {
  FlutterEventSink _eventSink;
}

@synthesize isStarted = _isStarted;

double degrees(double radians) {
  return (180/M_PI) * radians;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _isStarted = NO;
  }
  return self;
}

- (void)startSensors {
  // NSLog(@"AeyriumSensor: startSensors called, setting _isStarted to YES");
  _isStarted = YES;
  
  // Try to start immediately if we already have an event sink
  if (_eventSink) {
    // NSLog(@"AeyriumSensor: Event sink exists, attempting to start motion updates immediately");
    [self startMotionUpdatesIfNeeded];
  } else {
    // NSLog(@"AeyriumSensor: No event sink yet, will start when onListen is called");
  }
}

- (void)stopSensors {
  // NSLog(@"AeyriumSensor: stopSensors called, setting _isStarted to NO");
  _isStarted = NO;
  if (_motionManager) {
    // NSLog(@"AeyriumSensor: Stopping device motion updates");
    [_motionManager stopDeviceMotionUpdates];
  }
}

- (void)startMotionUpdatesIfNeeded {
  if (!_isStarted || !_eventSink) {
    // NSLog(@"AeyriumSensor: Cannot start motion updates - isStarted: %@, eventSink: %@", 
    //       _isStarted ? @"YES" : @"NO", 
    //       _eventSink ? @"exists" : @"nil");
    return;
  }
  
  _initMotionManager();
  
  if ([_motionManager isDeviceMotionActive]) {
    // NSLog(@"AeyriumSensor: Device motion already active");
    return;
  }
  
  // NSLog(@"AeyriumSensor: Starting device motion updates");
  NSError *error = nil;
  
  [_motionManager
   startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical
   toQueue:[[NSOperationQueue alloc] init]
   withHandler:^(CMDeviceMotion* data, NSError* error) {
     if (error) {
       // NSLog(@"AeyriumSensor: ERROR in motion handler - %@", error.localizedDescription);
       return;
     }
     
     if (!self.isStarted) {
       // NSLog(@"AeyriumSensor: Motion data received but sensor is stopped, ignoring");
       return;
     }
     
     if (!data) {
       // NSLog(@"AeyriumSensor: ERROR - No motion data received");
       return;
     }
     
     CMAttitude *attitude = data.attitude;
     CMQuaternion quat = attitude.quaternion;
   
     CMDeviceMotion *deviceMotion = data;
     
     // Correct for the rotation matrix not including the screen orientation:
     UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
     float deviceOrientationRadians = 0.0f;
//     if (orientation == UIDeviceOrientationLandscapeLeft) {
//       deviceOrientationRadians = M_PI_2;
//     }
//     if (orientation == UIDeviceOrientationLandscapeRight) {
//       deviceOrientationRadians = -M_PI_2;
//     }
//     if (orientation == UIDeviceOrientationPortraitUpsideDown) {
//       deviceOrientationRadians = M_PI;
//     }
     GLKMatrix4 baseRotation = GLKMatrix4MakeRotation(deviceOrientationRadians, 0.0f, 1.0f, 1.0f);
     
     GLKMatrix4 deviceMotionAttitudeMatrix;
     CMRotationMatrix a = deviceMotion.attitude.rotationMatrix;
     deviceMotionAttitudeMatrix
     = GLKMatrix4Make(a.m11, a.m21, a.m31, 0.0f,
                      a.m12, a.m22, a.m32, 0.0f,
                      a.m13, a.m23, a.m33, 0.0f,
                      0.0f, 0.0f, 0.0f, 1.0f);
     
     deviceMotionAttitudeMatrix = GLKMatrix4Multiply(baseRotation, deviceMotionAttitudeMatrix);
     // iOS attitude.yaw with XMagneticNorthZVertical reference frame
     // Adjust for device Y-axis pointing forward (subtract 90°) and flip 180°
     double myYaw = -(attitude.yaw - M_PI_2) + M_PI;

     // Match Android's sign conventions
     double pitch = -attitude.pitch;
     double roll = -attitude.roll;
     double rollGravity = atan2(data.gravity.x, data.gravity.y) - M_PI;
     
     dispatch_async(dispatch_get_main_queue(), ^{
       if (self->_eventSink) {
         sendData(pitch, rollGravity, myYaw, self->_eventSink);
       } else {
         // NSLog(@"AeyriumSensor: Event sink lost while sending data");
       }
     });
   }];
  
  // if ([_motionManager isDeviceMotionActive]) {
  //   NSLog(@"AeyriumSensor: Successfully started device motion updates");
  // } else {
  //   NSLog(@"AeyriumSensor: ERROR - Failed to start device motion updates");
  // }
}

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
  // NSLog(@"AeyriumSensor: onListen called, isStarted: %@", _isStarted ? @"YES" : @"NO");
  _eventSink = eventSink;
  
  if (_isStarted) {
    [self startMotionUpdatesIfNeeded];
  } else {
    // NSLog(@"AeyriumSensor: Sensor not started yet, waiting for start command");
  }
  
  return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
  // NSLog(@"AeyriumSensor: onCancel called, stopping device motion updates");
  [_motionManager stopDeviceMotionUpdates];
  _eventSink = nil;
  return nil;
}

@end
