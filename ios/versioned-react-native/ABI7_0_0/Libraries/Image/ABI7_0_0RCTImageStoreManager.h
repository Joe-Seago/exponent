// Copyright 2004-present Facebook. All Rights Reserved.

#import <UIKit/UIKit.h>

#import "ABI7_0_0RCTBridge.h"
#import "ABI7_0_0RCTURLRequestHandler.h"

@interface ABI7_0_0RCTImageStoreManager : NSObject <ABI7_0_0RCTURLRequestHandler>

/**
 * Set and get cached image data asynchronously. It is safe to call these from any
 * thread. The callbacks will be called on an unspecified thread.
 */
- (void)removeImageForTag:(NSString *)imageTag withBlock:(void (^)())block;
- (void)storeImageData:(NSData *)imageData withBlock:(void (^)(NSString *imageTag))block;
- (void)getImageDataForTag:(NSString *)imageTag withBlock:(void (^)(NSData *imageData))block;

/**
 * Convenience method to store an image directly (image is converted to data
 * internally, so any metadata such as scale or orientation will be lost).
 */
- (void)storeImage:(UIImage *)image withBlock:(void (^)(NSString *imageTag))block;

@end

@interface ABI7_0_0RCTImageStoreManager (Deprecated)

/**
 * These methods are deprecated - use the data-based alternatives instead.
 */
- (NSString *)storeImage:(UIImage *)image __deprecated;
- (UIImage *)imageForTag:(NSString *)imageTag __deprecated;
- (void)getImageForTag:(NSString *)imageTag withBlock:(void (^)(UIImage *image))block __deprecated;

@end

@interface ABI7_0_0RCTBridge (ABI7_0_0RCTImageStoreManager)

@property (nonatomic, readonly) ABI7_0_0RCTImageStoreManager *imageStoreManager;

@end
