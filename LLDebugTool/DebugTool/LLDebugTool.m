//
//  LLDebugTool.m
//
//  Copyright (c) 2018 LLDebugTool Software Foundation (https://github.com/HDB-Li/LLDebugTool)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import "LLDebugTool.h"

#import <pthread/pthread.h>

#import "LLComponentCore.h"
#import "LLComponentHandle.h"
#import "LLDebugToolMacros.h"
#import "LLLogDefine.h"
#import "LLRouter.h"
#import "LLTool.h"
#import "LLWindowManager.h"

#import "NSObject+LL_Runtime.h"

NSNotificationName const LLDebugToolStartWorkingNotification = @"LLDebugToolStartWorkingNotification";

LLDebugToolStartWorkingNotificationKey LLDebugToolStartWorkingConfigNotificationKey = @"LLDebugToolStartWorkingConfigNotificationKey";

static LLDebugTool *_instance = nil;

static pthread_mutex_t mutex_t = PTHREAD_MUTEX_INITIALIZER;

@interface LLDebugTool ()

@property (nonatomic, assign) BOOL installed;

@end

@implementation LLDebugTool

/**
 * Singleton
 @return Singleton
 */
+ (instancetype)sharedTool {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[LLDebugTool alloc] init];
        [_instance initial];
    });
    return _instance;
}

- (void)startWorking {
    pthread_mutex_lock(&mutex_t);
    if (_isWorking) {
        pthread_mutex_unlock(&mutex_t);
        return;
    }
    _isWorking = YES;
    [LLTool setStartWorkingAfterApplicationDidFinishLaunching:YES];
    pthread_mutex_unlock(&mutex_t);

    // Open crash helper
    [LLRouter setCrashHelperEnable:YES];
    // Open log helper
    [LLRouter setLogHelperEnable:YES];
    // Open network monitoring
    [LLRouter setNetworkHelperEnable:YES];
    // Open app monitoring
    [LLRouter setAppInfoHelperEnable:YES];
    // Open screenshot
    [LLRouter setScreenshotHelperEnable:YES];
    // Open setting
    [LLRouter setSettingHelperEnable:YES];
    // Open entry
    [LLDT_CC_Entry setEnabled:YES];
    // Open location
    if ([LLDebugConfig shared].mockLocation) {
        [LLRouter setLocationHelperEnable:YES];
    }
    // show window
    if (self.installed || ![LLDebugConfig shared].hideWhenInstall) {
        [LLComponentHandle executeAction:LLDebugToolActionEntry data:nil];
    }
    if (!self.installed) {
        // Check version.
        [self checkVersionAtGlobal];
    }
    self.installed = YES;
}

- (void)startWorkingWithConfigBlock:(void (^)(LLDebugConfig *config))configBlock {
    if (configBlock) {
        configBlock([LLDebugConfig shared]);
    }
    [self startWorking];
}

- (void)stopWorking {
    pthread_mutex_lock(&mutex_t);
    if (!_isWorking) {
        pthread_mutex_unlock(&mutex_t);
        return;
    }
    _isWorking = NO;
    [LLTool setStartWorkingAfterApplicationDidFinishLaunching:NO];
    pthread_mutex_unlock(&mutex_t);

    // Close entry
    [LLDT_CC_Entry setEnabled:NO];
    // Close location
    [LLRouter setLocationHelperEnable:NO];
    // Close setting
    [LLRouter setSettingHelperEnable:NO];
    // Close screenshot
    [LLRouter setScreenshotHelperEnable:NO];
    // Close app monitoring
    [LLRouter setAppInfoHelperEnable:NO];
    // Close network monitoring
    [LLRouter setNetworkHelperEnable:NO];
    // Close log helper
    [LLRouter setLogHelperEnable:NO];
    // Close crash helper
    [LLRouter setCrashHelperEnable:NO];
    // hide window
    [[LLWindowManager shared] removeAllVisibleWindows];
}

- (void)executeAction:(LLDebugToolAction)action {
    [LLComponentHandle executeAction:action data:nil];
}

+ (NSString *)version {
    return [self isBetaVersion] ? [[self versionNumber] stringByAppendingString:@"(BETA)"] : [self versionNumber];
}

+ (NSString *)versionNumber {
    return @"1.3.9";
}

+ (BOOL)isBetaVersion {
    return YES;
}

#pragma mark - Life Cycle
- (void)dealloc {
    [self unregisterNotifications];
}

#pragma mark - LLDebugToolStartWorkingNotification
- (void)didReceiveDebugToolStartWorkingNotification:(NSNotification *)notification {
    if (self.isWorking) {
        return;
    }

    NSDictionary *data = notification.userInfo[LLDebugToolStartWorkingConfigNotificationKey];
    if ([data isKindOfClass:[NSDictionary class]]) {
        NSArray *propertys = [LLDebugConfig LL_getPropertyNames];
        for (NSString *key in data) {
            if ([propertys containsObject:key]) {
                [[LLDebugConfig shared] setValue:data[key] forKey:key];
            }
        }
    }
    [self startWorking];
}

#pragma mark - Primary
- (void)initial {
    // Register notification
    [self registerNotifications];
}

- (void)checkVersionAtGlobal {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self checkVersion];
    });
}

- (void)checkVersion {
    [LLTool createDirectoryAtPath:[LLDebugConfig shared].folderPath];
    __block NSString *filePath = [[LLDebugConfig shared].folderPath stringByAppendingPathComponent:@"LLDebugTool.plist"];
    NSMutableDictionary *localInfo = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
    if (!localInfo) {
        localInfo = [[NSMutableDictionary alloc] init];
    }
    NSString *version = localInfo[@"version"];
    // localInfo will be nil before version 1.1.2
    if (!version) {
        version = @"0.0.0";
    }

    if ([[LLDebugTool versionNumber] compare:version] == NSOrderedDescending) {
        localInfo[@"version"] = [LLDebugTool versionNumber];
        [localInfo writeToFile:filePath atomically:YES];
    }

    if ([LLDebugTool isBetaVersion]) {
        // This method called in instancetype, can't use macros to log.
        [LLTool log:kLLDebugToolLogUseBetaAlert];
    }
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveDebugToolStartWorkingNotification:) name:LLDebugToolStartWorkingNotification object:nil];
}

- (void)unregisterNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation LLDebugTool (Component)

- (LLComponentCore *)componentCore {
    LLComponentCore *_componentCore = objc_getAssociatedObject(self, _cmd);
    if (!_componentCore) {
        _componentCore = [[LLComponentCore alloc] init];
        objc_setAssociatedObject(self, _cmd, _componentCore, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return _componentCore;
}

@end

@implementation LLDebugTool (Log)

- (void)logInFile:(NSString *)file function:(NSString *)function lineNo:(NSInteger)lineNo onEvent:(NSString *)onEvent message:(NSString *)message {
    [LLDT_CC_Log logInFile:file function:function lineNo:lineNo onEvent:onEvent message:message];
}

- (void)alertLogInFile:(NSString *)file function:(NSString *)function lineNo:(NSInteger)lineNo onEvent:(NSString *)onEvent message:(NSString *)message {
    [LLDT_CC_Log alertLogInFile:file function:function lineNo:lineNo onEvent:onEvent message:message];
}

- (void)warningLogInFile:(NSString *)file function:(NSString *)function lineNo:(NSInteger)lineNo onEvent:(NSString *)onEvent message:(NSString *)message {
    [LLDT_CC_Log warningLogInFile:file function:function lineNo:lineNo onEvent:onEvent message:message];
}

- (void)errorLogInFile:(NSString *)file function:(NSString *)function lineNo:(NSInteger)lineNo onEvent:(NSString *)onEvent message:(NSString *)message {
    [LLDT_CC_Log errorLogInFile:file function:function lineNo:lineNo onEvent:onEvent message:message];
}

@end
