//
//  NSTask.h
//  Santander
//
//  Created by Serena on 06/09/2022
//
	

#ifndef NSTask_h
#define NSTask_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTask : NSObject

@property (copy) NSArray <NSString *> *arguments;
@property (copy) NSURL *currentDirectoryURL;
@property (copy) NSDictionary *environment;
@property (copy) NSURL *executableURL;
@property (readonly) int processIdentifier;
@property NSInteger qualityOfService;
@property (getter=isRunning, readonly) BOOL running;
@property (retain) NSPipe *standardError;
@property (retain) id standardInput;
@property (retain) NSPipe *standardOutput;
@property(copy) void (^terminationHandler)(NSTask *);
@property (readonly) NSInteger terminationReason;
@property (readonly) int terminationStatus;


+(id)allocWithZone:(struct _NSZone *)arg0 ;
+(id)currentTaskDictionary;
+(id)launchedTaskWithDictionary:(id)arg0 ;
-(BOOL)isSpawnedProcessDisclaimed;
-(BOOL)resume;
-(BOOL)suspend;
-(NSInteger)suspendCount;
-(BOOL)launchAndReturnError:(out NSError * _Nullable *)error;
-(id)currentDirectoryPath;
-(id)init;
-(id)launchPath;
-(void)waitUntilExit;
-(void)interrupt;
-(void)launch;
-(void)setCurrentDirectoryPath:(id)arg0 ;
-(void)setLaunchPath:(id)arg0 ;
-(void)setSpawnedProcessDisclaimed:(BOOL)arg0 ;
-(void)terminate;

@end
NS_ASSUME_NONNULL_END

#endif /* NSTask_h */
