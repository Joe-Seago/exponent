// Copyright 2015-present 650 Industries. All rights reserved.

#import "ABI10_0_0EXAmplitude.h"

#import <Amplitude.h>
#import "ABI10_0_0EXVersionManager.h"

@interface ABI10_0_0EXAmplitude ()

@property (nonatomic, strong) NSString *escapedExperienceId;

@end

@implementation ABI10_0_0EXAmplitude

+ (NSString *)moduleName { return @"ExponentAmplitude"; }

- (instancetype)initWithExperienceId:(NSString *)experienceId
{
  if (self = [super init]) {
    _escapedExperienceId = [ABI10_0_0EXVersionManager escapedResourceName:experienceId];
  }
  return self;
}

ABI10_0_0RCT_EXPORT_METHOD(initialize:(NSString *)apiKey)
{
  // TODO: remove the UIApplicationWillEnterForegroundNotification and
  // UIApplicationDidEnterBackgroundNotification observers and call enterForeground
  // and enterBackground manually.
  [[Amplitude instanceWithName:_escapedExperienceId] initializeApiKey:apiKey];
}

ABI10_0_0RCT_EXPORT_METHOD(setUserId:(NSString *)userId)
{
  [[Amplitude instanceWithName:_escapedExperienceId] setUserId:userId];
}

ABI10_0_0RCT_EXPORT_METHOD(setUserProperties:(NSDictionary *)properties)
{
  [[Amplitude instanceWithName:_escapedExperienceId] setUserProperties:properties];
}

ABI10_0_0RCT_EXPORT_METHOD(clearUserProperties)
{
  [[Amplitude instanceWithName:_escapedExperienceId] clearUserProperties];
}

ABI10_0_0RCT_EXPORT_METHOD(logEvent:(NSString *)eventName)
{
  [[Amplitude instanceWithName:_escapedExperienceId] logEvent:eventName];
}

ABI10_0_0RCT_EXPORT_METHOD(logEventWithProperties:(NSString *)eventName withProperties:(NSDictionary *)properties)
{
  [[Amplitude instanceWithName:_escapedExperienceId] logEvent:eventName withEventProperties:properties];
}

ABI10_0_0RCT_EXPORT_METHOD(setGroup:(NSString *)groupType withGroupNames:(NSArray *)groupNames)
{
  [[Amplitude instanceWithName:_escapedExperienceId] setGroup:groupType groupName:groupNames];
}

@end
