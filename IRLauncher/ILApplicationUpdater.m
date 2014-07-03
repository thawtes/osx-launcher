//
//  ILApplicationUpdater.m
//  IRLauncher
//
//  Created by Masakazu Ohtsuka on 2014/06/30.
//  Copyright (c) 2014年 Masakazu Ohtsuka. All rights reserved.
//

#import "ILLog.h"
#import "ILApplicationUpdater.h"
#import <AutoUpdater/AUUpdater.h>
#import <AUtoupdater/AUUpdateChecker.h>
#import <AutoUpdater/AUGithubReleaseFetcher.h>
#import <AutoUpdater/AUZipUnarchiver.h>
#import <AutoUpdater/AUCodeSignValidator.h>
#import "NSObject-PerformWhenIdle.h"

static NSString * const kILUserDefaultsAutoUpdateKey  = @"autoupdate";
static NSString * const kILUserDefaultsLastCheckedKey = @"lastchecked";
static const NSTimeInterval kCheckInterval            = 24 * 60 * 60;
static const NSTimeInterval kIdleInterval             = 60;

@interface ILApplicationUpdater ()

@property (nonatomic) AUUpdateChecker *checker;
@property (nonatomic) AUUpdater *updater;
@property (nonatomic) NSTimer *checkTimer;

@end

@implementation ILApplicationUpdater

+ (instancetype) sharedInstance {
    static ILApplicationUpdater *instance;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        instance = [[ILApplicationUpdater alloc] init];
    });
    return instance;
}

- (void) startPeriodicCheck {
    if ([self enabled]) {
        [self startCheckTimer];
        [_checkTimer fire];
    }
}

- (void) enable: (BOOL)val {
    [[NSUserDefaults standardUserDefaults] setBool: val forKey: kILUserDefaultsAutoUpdateKey];

    if (val) {
        [self startCheckTimer];
    }
    else {
        [_checkTimer invalidate];
        _checkTimer = nil;
    }
}

- (BOOL) enabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey: kILUserDefaultsAutoUpdateKey];
}

- (void) runAndExit {
    NSString *version               = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    AUGithubReleaseFetcher *fetcher = [[AUGithubReleaseFetcher alloc] initWithUserName: @"mash" repositoryName: @"-----------------"]; // irkit/launcher-macos
    _checker = [[AUUpdateChecker alloc] initWithFetcher: fetcher
                                             unarchiver: [[AUZipUnarchiver alloc] init]
                                             validators: @[ [[AUCodeSignValidator alloc] init] ]];
    [_checker checkForVersionNewerThanVersion: version
                       foundNewerVersionBlock:^(NSDictionary *releaseInformation, NSURL *unarchivedBundlePath, NSError *error) {
        if (releaseInformation && unarchivedBundlePath && !error && [self enabled]) {
            _updater = [[AUUpdater alloc] initWithSourcePath: unarchivedBundlePath];
            [_updater runWithArgumentsForRelaunchedApplication: releaseInformation];
            [NSApp terminate: nil];
        }
    }];
}

#pragma mark - Timer related

- (void) startCheckTimer {
    if (_checkTimer) {
        [_checkTimer invalidate];
    }
    _checkTimer = [NSTimer scheduledTimerWithTimeInterval: kCheckInterval
                                                   target: self
                                                 selector: @selector(periodicCheck:)
                                                 userInfo: nil
                                                  repeats: YES];
}

- (void) periodicCheck:(NSTimer*) timer {
    if ([self enabled]) {
        // Delay til idle detected
        // User might want to use our app after a long idle, just before auto updating and exiting, but forget that.
        [self performSelector: @selector(runAndExit)
                   withObject: nil
          afterSystemIdleTime: kIdleInterval];
    }
}

@end