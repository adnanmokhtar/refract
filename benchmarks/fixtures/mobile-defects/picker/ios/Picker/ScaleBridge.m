#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(ScaleBridge, NSObject)

RCT_EXTERN_METHOD(readWeight:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(tare:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

@end
