#import <Flutter/Flutter.h>

@interface AeyriumSensorPlugin : NSObject<FlutterPlugin>
@end

@interface FLTSensorStreamHandler : NSObject<FlutterStreamHandler>
@property (nonatomic, assign) BOOL isStarted;
- (void)startSensors;
- (void)stopSensors;
@end