//
//  NJKeyRepeatManager.m
//  Enjoyable
//
//  Key repeat timer that emulates native macOS keyboard repeat:
//  - First keypress fires immediately
//  - After initialDelay, switches to steady repeat at repeatInterval
//  - All timers run on the main RunLoop in CommonModes
//    (so they fire even during UI tracking, matching system behavior)
//

#import "NJKeyRepeatManager.h"

// Read macOS system keyboard repeat settings from user defaults.
// InitialKeyRepeat: in 15ms ticks. 0 means "key repeat off".
// KeyRepeat: in 15ms ticks.
static NSTimeInterval systemInitialDelay(void) {
    NSInteger ticks = [[NSUserDefaults standardUserDefaults] integerForKey:@"InitialKeyRepeat"];
    if (ticks <= 0)
        ticks = 35; // ~525ms, macOS default
    return ticks * 0.015;
}

static NSTimeInterval systemRepeatInterval(void) {
    NSInteger ticks = [[NSUserDefaults standardUserDefaults] integerForKey:@"KeyRepeat"];
    if (ticks <= 0)
        ticks = 6; // ~90ms ≈ 11/sec, macOS default when slider is centered
    return ticks * 0.015;
}

@implementation NJKeyRepeatManager {
    NSTimer *_delayTimer;
    NSTimer *_repeatTimer;
    void (^_action)(void);
}

- (instancetype)init {
    if ((self = [super init])) {
        _initialDelay = systemInitialDelay();
        _repeatInterval = systemRepeatInterval();
    }
    return self;
}

- (void)dealloc {
    [self stopRepeating];
}

- (BOOL)isRepeating {
    return _delayTimer != nil || _repeatTimer != nil;
}

- (void)startRepeatingWithBlock:(void (^)(void))action {
    [self stopRepeating];
    _action = [action copy];

    // Schedule the initial delay timer.
    // When it fires, it creates the steady repeat timer.
    __weak __typeof(self) weakSelf = self;
    _delayTimer = [NSTimer timerWithTimeInterval:_initialDelay
                                         repeats:NO
                                           block:^(NSTimer * _Nonnull timer) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_delayTimer = nil;
        [strongSelf _startSteadyRepeat];
    }];
    // Use CommonModes so the timer fires during menu tracking, scrolling, etc.
    [NSRunLoop.mainRunLoop addTimer:_delayTimer forMode:NSRunLoopCommonModes];
}

- (void)_startSteadyRepeat {
    __weak __typeof(self) weakSelf = self;
    _repeatTimer = [NSTimer timerWithTimeInterval:_repeatInterval
                                          repeats:YES
                                            block:^(NSTimer * _Nonnull timer) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_action) {
            [timer invalidate];
            return;
        }
        strongSelf->_action();
    }];
    [NSRunLoop.mainRunLoop addTimer:_repeatTimer forMode:NSRunLoopCommonModes];
}

- (void)stopRepeating {
    [_delayTimer invalidate];
    _delayTimer = nil;
    [_repeatTimer invalidate];
    _repeatTimer = nil;
    _action = nil;
}

@end
