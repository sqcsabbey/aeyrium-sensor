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
      [sensorStreamHandler startSensors];
      result(nil);
    } else if ([@"stop" isEqualToString:call.method]) {
      [sensorStreamHandler stopSensors];
      result(nil);
    } else {
      result(FlutterMethodNotImplemented);
    }
  }];
}

@end

CMMotionManager* _motionManager;

void _initMotionManager() {
  if (!_motionManager) {
    _motionManager = [[CMMotionManager alloc] init];
    _motionManager.deviceMotionUpdateInterval = 0.03;
  }
}

static void sendData(Float64 pitch, Float64 roll,Float64 yaw, FlutterEventSink sink) {
  NSMutableData* event = [NSMutableData dataWithCapacity:2 * sizeof(Float64)];
  [event appendBytes:&pitch length:sizeof(Float64)];
  [event appendBytes:&roll length:sizeof(Float64)];
  [event appendBytes:&yaw length:sizeof(Float64)];
  sink([FlutterStandardTypedData typedDataWithFloat64:event]);
}


@implementation FLTSensorStreamHandler

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
  _isStarted = YES;
}

- (void)stopSensors {
  _isStarted = NO;
  if (_motionManager) {
    [_motionManager stopDeviceMotionUpdates];
  }
}

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
  _initMotionManager();
  if (_isStarted) {
    [_motionManager
     startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical toQueue:[[NSOperationQueue alloc] init]
     withHandler:^(CMDeviceMotion* data, NSError* error) {
       if (!self.isStarted) return;
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
     double pitch = (asin(-deviceMotionAttitudeMatrix.m22));
     double roll = -(atan2(2*(quat.y*quat.w - quat.x*quat.z), 1 - 2*quat.y*quat.y - 2*quat.z*quat.z)) ;
     double roll2 = -(atan2(-a.m13, a.m33)); //roll based on android code from matrix
     double rollGravity =  atan2(data.gravity.x, data.gravity.y) - M_PI; //roll based on just gravity
     double myYaw = asin(2*quat.x*quat.y + 2*quat.w*quat.z);
     dispatch_async(dispatch_get_main_queue(), ^{
       sendData(pitch, rollGravity , myYaw, eventSink);
     });
   }];
  }
  return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
  [_motionManager stopDeviceMotionUpdates];
  return nil;
}

@end
