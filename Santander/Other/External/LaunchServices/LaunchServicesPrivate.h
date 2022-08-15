//
//  LaunchServicesPrivate.h
//  Santander
//
//  Created by Serena on 15/08/2022.
//

#ifndef LaunchServicesPrivate_h
#define LaunchServicesPrivate_h
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSApplicationProxy
+ (LSApplicationProxy*)applicationProxyForIdentifier:(id)identifier;
- (NSString *)applicationIdentifier;
- (NSURL *)containerURL;
- (NSURL *)bundleURL;
- (NSString *)localizedName;
@end


@interface LSApplicationWorkspace
+ (instancetype) defaultWorkspace;
- (NSArray <LSApplicationProxy *>*)allInstalledApplications;
- (BOOL)openApplicationWithBundleID:(NSString *)arg0 ;
@end

@interface UIImage (Private)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString*)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

NS_ASSUME_NONNULL_END

#endif /* LaunchServicesPrivate_h */
