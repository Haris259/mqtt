#import "Mqtt.h"
#import <React/RCTEventEmitter.h>

@interface Mqtt ()
@property (strong, nonatomic) MQTTSessionManager *manager;
@property (nonatomic, strong) NSDictionary *defaultOptions;
@property (nonatomic, retain) NSMutableDictionary *options;
@property (nonatomic, strong) NSString *clientRef;
@property (nonatomic, strong) RCTEventEmitter *emitter;
@end

@implementation Mqtt

- (id)init {
    if ((self = [super init])) {
        self.defaultOptions = @{
                                @"host": @"localhost",
                                @"port": @1883,
                                @"protcol": @"tcp", //ws
                                @"tls": @NO,
                                @"keepalive": @120, //second
                                @"clientId" : @"react-native-mqtt",
                                @"protocolLevel": @4,
                                @"clean": @YES,
                                @"auth": @NO,
                                @"user": @"",
                                @"pass": @"",
                                @"will": @NO,
                                @"willMsg": [NSNull null],
                                @"willtopic": @"",
                                @"willQos": @0,
                                @"willRetainFlag": @NO
                                };
    }
    return self;
}

- (instancetype)initWithEmitter:(RCTEventEmitter *)emitter
                        options:(NSDictionary *)options
                      clientRef:(NSString *)clientRef {
    self = [self init];
    self.emitter = emitter;
    self.clientRef = clientRef;
    self.options = [NSMutableDictionary dictionaryWithDictionary:self.defaultOptions]; // Set default options
    for (NSString *key in options.keyEnumerator) { // Replace default options
        [self.options setValue:options[key] forKey:key];
    }
    return self;
}

- (void)connect {
    MQTTSSLSecurityPolicy *securityPolicy = nil;
    if(self.options[@"tls"]) {
        securityPolicy = [MQTTSSLSecurityPolicy policyWithPinningMode:MQTTSSLPinningModeNone];
        securityPolicy.allowInvalidCertificates = YES;
    }
    NSData *willMsg = nil;
    if(self.options[@"willMsg"] != [NSNull null]) {
        willMsg = [self.options[@"willMsg"] dataUsingEncoding:NSUTF8StringEncoding];
    }
    if (!self.manager) {
        dispatch_queue_t queue = dispatch_queue_create("com.hawking.app.anchor.mqtt", NULL);
        self.manager = [[MQTTSessionManager alloc] initWithPersistence:YES maxWindowSize:MQTT_MAX_WINDOW_SIZE maxMessages:MQTT_MAX_MESSAGES maxSize:MQTT_MAX_SIZE maxConnectionRetryInterval:60.0 connectInForeground:YES streamSSLLevel:nil queue: queue];
        self.manager.delegate = self;
        MQTTCFSocketTransport *transport = [[MQTTCFSocketTransport alloc] init];
        transport.host = [self.options valueForKey:@"host"];
        transport.port = [self.options[@"port"] intValue];
        transport.voip = YES;
        self.manager.session.transport = transport;
        [self.manager connectTo:[self.options valueForKey:@"host"]
                           port:[self.options[@"port"] intValue]
                            tls:[self.options[@"tls"] boolValue]
                      keepalive:[self.options[@"keepalive"] intValue]
                          clean:[self.options[@"clean"] intValue]
                           auth:[self.options[@"auth"] boolValue]
                           user:[self.options valueForKey:@"user"]
                           pass:[self.options valueForKey:@"pass"]
                           will:[self.options[@"will"] boolValue]
                      willTopic:[self.options valueForKey:@"willTopic"]
                        willMsg:willMsg
                        willQos:(MQTTQosLevel)[self.options[@"willQos"] intValue]
                 willRetainFlag:[self.options[@"willRetainFlag"] boolValue]
                   withClientId:[self.options valueForKey:@"clientId"]
                 securityPolicy:securityPolicy
                   certificates:nil
                  protocolLevel:MQTTProtocolVersion311
                 connectHandler:^(NSError *error) {
         }];
    } else {
        [self.manager connectToLast:^(NSError *error) {
        }];
    }
}

- (void)sessionManager:(MQTTSessionManager *)sessonManager didChangeState:(MQTTSessionManagerState)newState {
    switch (newState) {
        case MQTTSessionManagerStateClosed:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"closed",
                                              @"clientRef": self.clientRef,
                                              @"message": @"closed"
                                              }];
            break;
        case MQTTSessionManagerStateClosing:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"closing",
                                              @"clientRef": self.clientRef,
                                              @"message": @"closing"
                                              }];
            break;
        case MQTTSessionManagerStateConnected:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"connect",
                                              @"clientRef": self.clientRef,
                                              @"message": @"connected"
                                              }];
            break;
        case MQTTSessionManagerStateConnecting:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"connecting",
                                              @"clientRef": self.clientRef,
                                              @"message": @"connecting"
                                              }];
            break;
        case MQTTSessionManagerStateError: {
            NSError *lastError = self.manager.lastErrorCode;
            NSString *errorMsg = [NSString stringWithFormat:@"error: %@", [lastError localizedDescription]];
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"error",
                                              @"clientRef": self.clientRef,
                                              @"message": errorMsg
                                              }];
            break;
        }
        case MQTTSessionManagerStateStarting:

        default:
            break;
    }
}

- (void)messageDelivered:(UInt16)msgID {
    NSLog(@"messageDelivered");
    NSString *codeString = [NSString stringWithFormat:@"%d", msgID];
    [self.emitter sendEventWithName:@"mqtt_events"
                               body:@{@"event": @"msgSent",
                                      @"clientRef": self.clientRef,
                                      @"message": codeString
                                      }];
}

- (void)disconnect {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [self.manager disconnectWithDisconnectHandler:^(NSError *error) {
    }];
}

- (BOOL)isConnected {
    if (self.manager.session.status == MQTTSessionStatusConnected) {
        return true;
    }
    return false;
}

- (BOOL)isSubbed:(NSString *)topic {
    if ([self.manager.subscriptions objectForKey:topic]) {
        return true;
    }
    return false;
}

- (NSMutableArray *)getTopics {
    NSMutableArray *ret = [NSMutableArray array];
    int i = 0;
    for (id key in self.manager.subscriptions) {
        id keySet = [NSDictionary sharedKeySetForKeys:@[@"topic", @"qos"]];
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithSharedKeySet:keySet];
        tmp[@"topic"] = key;
        tmp[@"qos"] = [self.manager.subscriptions objectForKey:key];
        ret[i] = tmp;
        i++;
    }
    return ret;
}

- (void)subscribe:(NSString *)topic qos:(NSNumber *)qos {
    NSMutableDictionary *subscriptions = [self.manager.subscriptions mutableCopy];
    [subscriptions setObject:qos forKey:topic];
    [self.manager setSubscriptions:subscriptions];
}

- (void)unsubscribe:(NSString *)topic {
    NSMutableDictionary *subscriptions = [self.manager.subscriptions mutableCopy];
    [subscriptions removeObjectForKey:topic];
    [self.manager setSubscriptions:subscriptions];
}

- (void)publish:(NSString *)topic data:(NSData *)data qos:(NSNumber *)qos retain:(BOOL)retain {
    [self.manager sendData:data topic:topic qos:[qos intValue] retain:retain];
}



- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid {
   
}
- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    NSLog(@"dataStringMusab");
      dispatch_queue_t queue = dispatch_queue_create("com.hawking.app.anchor.mqtt", NULL);
    const unsigned char *bytes = [data bytes];
        NSUInteger length = [data length];
        NSMutableArray *arrayByte = [NSMutableArray arrayWithCapacity:length];
        
        for (NSUInteger i = 0; i < length; i++) {
            [arrayByte addObject:@(bytes[i])];
        }
     NSDictionary *body=@{
                        @"event": @"message",
                                      @"clientRef": self.clientRef,
                                      @"message": @{
                                              @"topic": topic,
                                            @"data_original":arrayByte,
                                              @"data": @"",
                                              @"retain": [NSNumber numberWithBool:retained]
                                              }
                                      };
     [self.emitter sendEventWithName:@"mqtt_events"
                               body:body
                                      ];

    
}
- (void)dealloc {
    [self disconnect];
}

@end
// - (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid {
//                                 body:@{
//                                       @"event": @"message",
//                                       @"clientRef": self.clientRef,
//                                       @"message": @{
//                                               @"topic": topic,
//                                               @"data_original": data,
//                                               @"retain": [NSNumber numberWithBool:retained]
//                                               }
// }
//- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
//    NSLog(@"message: %@", @{@"topic": topic, @"data": data});
//    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    [self.emitter sendEventWithName:@"mqtt_events"
//                               body:@{
//                                      @"event": @"message",
//                                      @"clientRef": self.clientRef,
//                                      @"message": @{
//                                              @"topic": topic,
//                                              @"data": dataString,
//                                              @"data_original": data,
//                                              @"retain": [NSNumber numberWithBool:retained]
//                                              }
//                                      }];

// - (void)dealloc {
//     [self disconnect];
// }

// @end
