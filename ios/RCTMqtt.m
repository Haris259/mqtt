#import <React/RCTBridgeModule.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>
// Project imports
#import "RCTMqtt.h"
#import "Mqtt.h"
@interface RCTMqtt ()
@property NSMutableDictionary *clients;
@end
@implementation RCTMqtt
{
    bool hasListeners;
}
RCT_EXPORT_MODULE();
+ (BOOL)requiresMainQueueSetup {
    return NO;
}
- (instancetype)init {
    if ((self = [super init])) {
        _clients = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)sendEventWithName:(NSString *)name body:(id)body {
    if (hasListeners && self.bridge) { // Only send events if anyone is listening
        [super sendEventWithName:name body:body];
    }
}
- (NSArray<NSString *> *)supportedEvents {
    return @[ @"mqtt_events" ];
}
// Will be called when this module's first listener is added.
- (void)startObserving {
    hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}
// Will be called when this module's last listener is removed, or on dealloc.
- (void)stopObserving {
    hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}
RCT_EXPORT_METHOD(createClient:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    NSString *clientRef = [[NSProcessInfo processInfo] globallyUniqueString];
    Mqtt *client = [[Mqtt allocWithZone:nil] initWithEmitter:self options:options clientRef:clientRef];
    [[self clients] setObject:client forKey:clientRef];
    resolve(clientRef);
}
RCT_EXPORT_METHOD(removeClient:(nonnull NSString *)clientRef) {
    [[self clients] removeObjectForKey:clientRef];
}
RCT_EXPORT_METHOD(connect:(nonnull NSString *)clientRef) {
    [[[self clients] objectForKey:clientRef] connect];
}
RCT_EXPORT_METHOD(disconnect:(nonnull NSString *)clientRef) {
    [[[self clients] objectForKey:clientRef] disconnect];
}
RCT_EXPORT_METHOD(isConnected:(nonnull NSString *)clientRef resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if ([[self clients] objectForKey:clientRef]) {
        BOOL conn = [[[self clients] objectForKey:clientRef] isConnected];
        resolve(@(conn));
    } else {
        NSError *error = [[NSError alloc] initWithDomain:@"com.kuhmute.kca" code:404 userInfo:@{@"Error reason": @"Client Not Found"}];
        reject(@"client_not_found", @"This client doesn't exist", error);
    }
}
RCT_EXPORT_METHOD(isSubbed:(nonnull NSString *)clientRef topic:(nonnull NSString *)topic resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if ([[self clients] objectForKey:clientRef]) {
        BOOL subbed = [[[self clients] objectForKey:clientRef] isSubbed:topic];
        resolve(@(subbed));
    } else {
        NSError *error = [[NSError alloc] initWithDomain:@"com.kuhmute.kca" code:404 userInfo:@{@"Error reason": @"Client Not Found"}];
        reject(@"client_not_found", @"This client doesn't exist", error);
    }
}
RCT_EXPORT_METHOD(getTopics:(nonnull NSString *)clientRef resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if ([[self clients] objectForKey:clientRef]) {
        NSMutableArray *ret = [[[self clients] objectForKey:clientRef] getTopics];
        resolve(ret);
    } else {
        NSError *error = [[NSError alloc] initWithDomain:@"com.kuhmute.kca" code:404 userInfo:@{@"Error reason": @"Client Not Found"}];
        reject(@"client_not_found", @"This client doesn't exist", error);
    }
}
RCT_EXPORT_METHOD(disconnectAll) {
    if (self.clients.count > 0) {
        for (NSString *aClientRef in self.clients) {
            [[[self clients] objectForKey:aClientRef] disconnect];
        }
    }
}
RCT_EXPORT_METHOD(subscribe:(nonnull NSString *)clientRef topic:(NSString *)topic qos:(nonnull NSNumber *)qos) {
    [[[self clients] objectForKey:clientRef] subscribe:topic qos:qos];
}
RCT_EXPORT_METHOD(unsubscribe:(nonnull NSString *)clientRef topic:(NSString *)topic) {
    [[[self clients] objectForKey:clientRef] unsubscribe:topic];
}
RCT_EXPORT_METHOD(publish:(nonnull NSString *) clientRef topic:(NSString *)topic data:(NSString*)data qos:(nonnull NSNumber *)qos retain:(BOOL)retain) {
    [[[self clients] objectForKey:clientRef] publish:topic
                                                data:[data dataUsingEncoding:NSUTF8StringEncoding]
                                                 qos:qos
                                              retain:retain];
}
// publishBuffer start
RCT_EXPORT_METHOD(publishBuffer:(nonnull NSString *)clientRef
                          topic:(NSString *)topic
                           data:(NSArray<NSNumber *> *)data
                            qos:(nonnull NSNumber *)qos
                         retain:(BOOL)retain) {
    [[[self clients] objectForKey:clientRef] publishBuffer:topic
                                               data:data
                                                qos:qos
                                             retain:retain];
}
- (NSData *)convertArrayToNSData:(NSArray<NSNumber *> *)array {
    NSMutableData *data = [NSMutableData dataWithCapacity:[array count]];
    for (NSNumber *number in array) {
        uint8_t byte = [number unsignedCharValue];
        [data appendBytes:&byte length:1];
    }
    return data;
}
// publishBuffer end
- (void)invalidate {
    [self disconnectAll];
}
- (void)dealloc {
}
@end