//
//  NJKeyRepeatManager.h
//  Enjoyable
//
//  Key repeat timer manager that emulates macOS native keyboard
//  repeat behavior: initial delay followed by steady repeat rate.
//

#import <Foundation/Foundation.h>

@interface NJKeyRepeatManager : NSObject

// Time before repeat begins (default: read from system, ~0.5s)
@property (nonatomic, assign) NSTimeInterval initialDelay;

// Interval between repeats (default: read from system, ~0.143s = ~7/sec)
@property (nonatomic, assign) NSTimeInterval repeatInterval;

@property (nonatomic, readonly) BOOL isRepeating;

// Start repeating: fires `action` once immediately, then after
// initialDelay switches to steady repeatInterval firing.
- (void)startRepeatingWithBlock:(void(^)(void))action;

// Stop all repeating and invalidate timers.
- (void)stopRepeating;

@end
