// Copyright 2015-present 650 Industries. All rights reserved.

#import "EXFrame.h"

#import "EXAnalytics.h"
#import "EXKernel.h"
#import "EXAppLoadingManager.h"
#import "EXFrameReactAppManager.h"

#import "RCTBridge.h"
#import "RCTExceptionsManager.h"
#import "UIView+React.h"

#define EX_FRAME_RELOAD_DEBOUNCE_SEC 0.05

NS_ASSUME_NONNULL_BEGIN

@interface EXFrame () <EXReactAppManagerDelegate, RCTInvalidating, RCTExceptionsManagerDelegate>

@property (nonatomic, assign) BOOL sourceSet;
@property (nonatomic, assign) BOOL needsReload;

@property (nonatomic, copy) RCTDirectEventBlock onLoadingStart;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingFinish;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingError;
@property (nonatomic, copy) RCTDirectEventBlock onError;

@property (nonatomic, strong) NSTimer *viewTestTimer;
@property (nonatomic, strong) NSTimer *tmrReload;

@property (nonatomic, strong) EXFrameReactAppManager *appManager;

@end

@implementation EXFrame

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)coder)

- (instancetype)init
{
  if (self = [super init]) {
    _appManager = [[EXFrameReactAppManager alloc] initWithFrame:self];
    _appManager.delegate = self;
  }
  return self;
}

- (void)dealloc
{
  [self invalidate];
}

#pragma mark - Invalidation

- (void)invalidate
{
  if (_tmrReload) {
    [_tmrReload invalidate];
    _tmrReload = nil;
  }
  [_appManager invalidate];
  if (_viewTestTimer) {
    [_viewTestTimer invalidate];
    _viewTestTimer = nil;
  }
  
  _sourceSet = NO;
  _needsReload = NO;
}

#pragma mark - Setting Properties

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
  NSSet <NSString *> *changedPropsSet = [NSSet setWithArray:changedProps];
  NSSet <NSString *> *propsForReload = [NSSet setWithArray:@[
    @"initialUri", @"manifest", @"source", @"applicationKey", @"debuggerHostname", @"debuggerPort",
  ]];
  if ([changedPropsSet intersectsSet:propsForReload]) {
    if ([self validateProps:changedProps]) {
      _needsReload = YES;
      [self performSelectorOnMainThread:@selector(_checkForReload) withObject:nil waitUntilDone:YES];
    } else {
      if (_tmrReload) {
        [_tmrReload invalidate];
        _tmrReload = nil;
      }
    }
  }
}

- (BOOL)validateProps:(NSArray<NSString *> *)changedProps
{
  BOOL isValid = YES;
  if ([changedProps containsObject:@"manifest"]) {
    if (!_manifest || ![_manifest objectForKey:@"id"]) {
      // we can't load an experience with no id
      NSDictionary *errorInfo = @{
                                  NSLocalizedDescriptionKey: @"Cannot open an experience with no id",
                                  NSLocalizedFailureReasonErrorKey: @"Tried to load a manifest with no experience id, or a null manifest",
                                  };
      [self _sendLoadingError:[NSError errorWithDomain:kEXKernelErrorDomain code:-1 userInfo:errorInfo]];
      isValid = NO;
    }
  }
  if ([changedProps containsObject:@"source"]) {
    // Performed in additon to JS-side validation because RN iOS websockets will crash without a port.
    _source = [[self class] _ensureUrlHasPort:_source];
    if (_source) {
      _sourceSet = YES;
    } else {
      // we had issues with this bundle url
      NSDictionary *errorInfo = @{
                                  NSLocalizedDescriptionKey: @"Cannot open the given bundle url",
                                  NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:@"Cannot parse bundle url %@", [_source absoluteString]],
                                  };
      [self _sendLoadingError:[NSError errorWithDomain:kEXKernelErrorDomain code:-1 userInfo:errorInfo]];
      isValid = NO;
    }
  }
  return isValid;
}

- (void)reload
{
  if ([self validateProps:@[ @"manifest", @"source" ]]) {
    [[EXAnalytics sharedInstance] logEvent:@"RELOAD_EXPERIENCE" manifestUrl:_source eventProperties:nil];
    [_appManager reload];
  }
}

- (void)_checkForReload
{
  EXAssertMainThread();
  if (_needsReload) {
    if (_sourceSet && _source) {
      [[EXAnalytics sharedInstance] logEvent:@"LOAD_EXPERIENCE" manifestUrl:_source eventProperties:nil];
    }
    _sourceSet = NO;
    _needsReload = NO;
    
    if (_tmrReload) {
      [_tmrReload invalidate];
      _tmrReload = nil;
    }
    _tmrReload = [NSTimer scheduledTimerWithTimeInterval:EX_FRAME_RELOAD_DEBOUNCE_SEC target:_appManager selector:@selector(reload) userInfo:nil repeats:NO];
  }
}

#pragma mark - Layout

- (void)layoutSubviews
{
  [super layoutSubviews];
  if (_appManager.reactRootView) {
    _appManager.reactRootView.frame = self.bounds;
  }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
  if (_manifest) {
    NSString *orientationConfig = _manifest[@"orientation"];
    if ([orientationConfig isEqualToString:@"portrait"]) {
      // lock to portrait
      return UIInterfaceOrientationMaskPortrait;
    } else if ([orientationConfig isEqualToString:@"landscape"]) {
      // lock to landscape
      return UIInterfaceOrientationMaskLandscape;
    }
  }
  // no config or default value: allow autorotation
  return UIInterfaceOrientationMaskAllButUpsideDown;
}

/**
 *  If a developer has locked their experience to a particular orientation,
 *  but some other experience has allowed the device to rotate to something unsupported,
 *  attempt to resolve that discrepancy here by forcing the device to rotate.
 */
- (void)enforceDesiredDeviceOrientation
{
  EXAssertMainThread();
  UIInterfaceOrientationMask mask = [self supportedInterfaceOrientations];
  UIDeviceOrientation currentOrientation = [[UIDevice currentDevice] orientation];
  if (mask == UIInterfaceOrientationMaskLandscape && (currentOrientation == UIDeviceOrientationPortrait)) {
    [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationLandscapeLeft) forKey:@"orientation"];
  } else if (mask == UIInterfaceOrientationMaskPortrait && (currentOrientation != UIDeviceOrientationPortrait)) {
    [[UIDevice currentDevice] setValue:@(UIDeviceOrientationPortrait) forKey:@"orientation"];
  }
  [UIViewController attemptRotationToDeviceOrientation];
}

#pragma mark - EXReactAppManagerDelegate

- (void)reactAppManagerDidInitApp:(EXReactAppManager *)appManager
{
  UIView *reactRootView = appManager.reactRootView;
  reactRootView.frame = self.bounds;
  [self addSubview:reactRootView];
}

- (void)reactAppManagerDidDestroyApp:(EXReactAppManager *)appManager
{
  if (_tmrReload) {
    [_tmrReload invalidate];
    _tmrReload = nil;
  }
}

- (void)reactAppManagerStartedLoadingJavaScript:(EXReactAppManager *)appManager
{
  if (_onLoadingStart) {
    _onLoadingStart(nil);
  }
}

- (void)reactAppManagerFinishedLoadingJavaScript:(EXReactAppManager *)appManager
{
  if (_viewTestTimer) {
    [_viewTestTimer invalidate];
  }
  _viewTestTimer = [NSTimer scheduledTimerWithTimeInterval:0.02
                                                    target:self
                                                  selector:@selector(_checkAppFinishedLoading:)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)reactAppManager:(EXReactAppManager *)appManager failedToLoadJavaScriptWithError:(NSError *)error
{
  [self _sendLoadingError:error];
}

- (void)reactAppManager:(EXReactAppManager *)appManager failedToDownloadBundleWithError:(NSError *)error
{
  
}

- (void)reactAppManagerDidForeground:(EXReactAppManager *)appManager
{
  if (_debuggerHostname) {
    [[NSUserDefaults standardUserDefaults] setObject:_debuggerHostname forKey:@"websocket-executor-hostname"];
  } else {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"websocket-executor-hostname"];
  }
  if (_debuggerPort != -1) {
    [[NSUserDefaults standardUserDefaults] setInteger:_debuggerPort forKey:@"websocket-executor-port"];
  } else {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"websocket-executor-port"];
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self enforceDesiredDeviceOrientation];
  });
}

#pragma mark - Internal

- (void)_checkAppFinishedLoading:(NSTimer *)timer
{
  // When root view has been filled with something, there are two cases:
  //   1. AppLoading was never mounted, in which case we hide the loading indicator immediately
  //   2. AppLoading was mounted, in which case we wait till it is unmounted to hide the loading indicator
  if (_appManager.reactRootView &&
      _appManager.reactRootView.subviews.count > 0 &&
      _appManager.reactRootView.subviews.firstObject.subviews.count > 0) {
    EXAppLoadingManager *appLoading = nil;
    for (Class class in [_appManager.reactBridge moduleClasses]) {
      if ([class isSubclassOfClass:[EXAppLoadingManager class]]) {
        appLoading = [_appManager.reactBridge moduleForClass:[EXAppLoadingManager class]];
        break;
      }
    }
    if (!appLoading || !appLoading.started || appLoading.finished) {
      if (_onLoadingFinish) {
        _onLoadingFinish(nil);
      }
      [_viewTestTimer invalidate];
      _viewTestTimer = nil;
    }
  }
}

- (void)_sendLoadingError: (NSError *)error
{
  [[EXKernel sharedInstance].bridgeRegistry setError:error forBridge:_appManager.reactBridge];
  if (_onLoadingError) {
    NSMutableDictionary *event = [@{
                                    @"domain": error.domain,
                                    @"code": @(error.code),
                                    @"description": error.localizedDescription,
                                    } mutableCopy];
    if (error.localizedFailureReason) {
      event[@"reason"] = error.localizedFailureReason;
    }
    if (error.userInfo && error.userInfo[@"stack"]) {
      event[@"stack"] = error.userInfo[@"stack"];
    }
    _onLoadingError(event);
  }
}

+ (NSURL *)_ensureUrlHasPort:(NSURL *)url
{
  NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
  if (components) {
    NSString *host = components.host;
    if (host) {
      if (!components.port) {
        if ([url.scheme isEqualToString:@"https"] || [url.scheme isEqualToString:@"exps"]) {
          components.port = @443;
        } else {
          components.port = @80;
        }
      }
      return [components URL];
    }
  }
  return nil;
}

# pragma mark - RCTExceptionsManagerDelegate

- (void)handleSoftJSExceptionWithMessage:(NSString *)message stack:(NSArray *)stack exceptionId:(NSNumber *)exceptionId
{
  // send the error to the JS console
  if (_onError) {
    _onError(@{
               @"id": exceptionId,
               @"message": message,
               @"stack": stack,
               @"fatal": @(NO),
               });
  }
}

- (void)handleFatalJSExceptionWithMessage:(NSString *)message stack:(NSArray *)stack exceptionId:(NSNumber *)exceptionId
{
  // send the error to the JS console
  if (_onError) {
    _onError(@{
               @"id": exceptionId,
               @"message": message,
               @"stack": stack,
               @"fatal": @(YES),
               });
  }
}

- (void)updateJSExceptionWithMessage:(NSString *)message stack:(NSArray *)stack exceptionId:(NSNumber *)exceptionId
{
  // send the error to the JS console
  if (_onError) {
    _onError(@{
               @"id": exceptionId,
               @"message": message,
               @"stack": stack,
               });
  }
}

@end

NS_ASSUME_NONNULL_END
