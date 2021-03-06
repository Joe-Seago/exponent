/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI7_0_0RCTNetInfo.h"

#import "ABI7_0_0RCTAssert.h"
#import "ABI7_0_0RCTBridge.h"
#import "ABI7_0_0RCTEventDispatcher.h"

static NSString *const ABI7_0_0RCTReachabilityStateUnknown = @"unknown";
static NSString *const ABI7_0_0RCTReachabilityStateNone = @"none";
static NSString *const ABI7_0_0RCTReachabilityStateWifi = @"wifi";
static NSString *const ABI7_0_0RCTReachabilityStateCell = @"cell";

@implementation ABI7_0_0RCTNetInfo
{
  SCNetworkReachabilityRef _reachability;
  NSString *_status;
}

@synthesize bridge = _bridge;

ABI7_0_0RCT_EXPORT_MODULE()

static void ABI7_0_0RCTReachabilityCallback(__unused SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
  ABI7_0_0RCTNetInfo *self = (__bridge id)info;
  NSString *status = ABI7_0_0RCTReachabilityStateUnknown;
  if ((flags & kSCNetworkReachabilityFlagsReachable) == 0 ||
      (flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0) {
    status = ABI7_0_0RCTReachabilityStateNone;
  }

#if TARGET_OS_IPHONE

  else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
    status = ABI7_0_0RCTReachabilityStateCell;
  }

#endif

  else {
    status = ABI7_0_0RCTReachabilityStateWifi;
  }

  if (![status isEqualToString:self->_status]) {
    self->_status = status;
    [self->_bridge.eventDispatcher sendDeviceEventWithName:@"networkStatusDidChange"
                                                      body:@{@"network_info": status}];
  }
}

#pragma mark - Lifecycle

- (instancetype)initWithHost:(NSString *)host
{
  ABI7_0_0RCTAssertParam(host);
  ABI7_0_0RCTAssert(![host hasPrefix:@"http"], @"Host value should just contain the domain, not the URL scheme.");

  if ((self = [super init])) {
    _status = ABI7_0_0RCTReachabilityStateUnknown;
    _reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, host.UTF8String);
    SCNetworkReachabilityContext context = { 0, ( __bridge void *)self, NULL, NULL, NULL };
    SCNetworkReachabilitySetCallback(_reachability, ABI7_0_0RCTReachabilityCallback, &context);
    SCNetworkReachabilityScheduleWithRunLoop(_reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
  }
  return self;
}

- (instancetype)init
{
  return [self initWithHost:@"apple.com"];
}

- (void)dealloc
{
  SCNetworkReachabilityUnscheduleFromRunLoop(_reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
  CFRelease(_reachability);
}

#pragma mark - Public API

// TODO: remove error callback - not needed except by Subscribable interface
ABI7_0_0RCT_EXPORT_METHOD(getCurrentConnectivity:(ABI7_0_0RCTPromiseResolveBlock)resolve
                  reject:(__unused ABI7_0_0RCTPromiseRejectBlock)reject)
{
  resolve(@{@"network_info": _status});
}

@end
