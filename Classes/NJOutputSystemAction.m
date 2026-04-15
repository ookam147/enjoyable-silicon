//
//  NJOutputSystemAction.m
//  Enjoyable
//
//  Triggers macOS system-level actions via multiple fallback methods:
//  1. CoreDock private API (fastest, no subprocess)
//  2. NSAppleScript fallback for space switching
//

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Carbon/Carbon.h>
#import <dlfcn.h>

#import "NJOutputSystemAction.h"

// Private CoreDock API — stable since macOS 10.6, used by many third-party tools.
// Dynamically loaded to avoid linker dependency.
typedef void (*CoreDockSendNotificationFunc)(CFStringRef);

static CoreDockSendNotificationFunc _GetCoreDockSendNotification(void) {
    static CoreDockSendNotificationFunc func = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
        if (handle) {
            func = (CoreDockSendNotificationFunc)dlsym(handle, "CoreDockSendNotification");
        }
    });
    return func;
}

// Fallback: run AppleScript
static void _RunAppleScript(NSString *source) {
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    [script executeAndReturnError:nil];
}

// CGEvent-based source for space switching key simulation
static CGEventSourceRef _NJHIDSource(void) {
    static CGEventSourceRef source;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    });
    return source;
}

@implementation NJOutputSystemAction

+ (NSArray<NSString *> *)actionTitles {
    return @[
        @"Mission Control",
        @"App Exposé (应用窗口)",
        @"Show Desktop (显示桌面)",
        @"Launchpad (启动台)",
        @"← Move Left Space (左移空间)",
        @"→ Move Right Space (右移空间)",
    ];
}

+ (NSString *)serializationCode {
    return @"system action";
}

- (NSDictionary *)serialize {
    return @{ @"type": self.class.serializationCode,
              @"action": @(_action) };
}

+ (NJOutput *)outputWithSerialization:(NSDictionary *)serialization {
    NJOutputSystemAction *output = [[NJOutputSystemAction alloc] init];
    output.action = (NJSystemAction)[serialization[@"action"] integerValue];
    return output;
}

- (void)trigger {
    CoreDockSendNotificationFunc coreDockSend = _GetCoreDockSendNotification();

    switch (_action) {
        case NJSystemActionMissionControl:
            if (coreDockSend) {
                coreDockSend(CFSTR("com.apple.expose.awesomebar"));
            } else {
                _RunAppleScript(@"tell application \"Mission Control\" to launch");
            }
            break;

        case NJSystemActionAppExpose:
            if (coreDockSend) {
                coreDockSend(CFSTR("com.apple.expose.front.awesomebar"));
            } else {
                _RunAppleScript(@"tell application \"Mission Control\" to launch");
            }
            break;

        case NJSystemActionShowDesktop:
            if (coreDockSend) {
                coreDockSend(CFSTR("com.apple.showDesktop"));
            } else {
                _RunAppleScript(@"tell application \"System Events\" to key code 160");
            }
            break;

        case NJSystemActionLaunchpad:
            if (coreDockSend) {
                coreDockSend(CFSTR("com.apple.launchpad.toggle"));
            } else {
                [[NSWorkspace sharedWorkspace] openURL:
                    [NSURL fileURLWithPath:@"/System/Applications/Launchpad.app"]];
            }
            break;

        case NJSystemActionMoveLeftSpace: {
            // Ctrl+Left arrow to switch to left space
            CGEventRef flagDown = CGEventCreateKeyboardEvent(_NJHIDSource(), kVK_Control, YES);
            CGEventSetType(flagDown, kCGEventFlagsChanged);
            CGEventSetFlags(flagDown, kCGEventFlagMaskControl);
            CGEventPost(kCGHIDEventTap, flagDown);
            CFRelease(flagDown);

            // Use AppleScript as the reliable method for space switching
            _RunAppleScript(@"tell application \"System Events\" to key code 123 using control down");

            CGEventRef flagUp = CGEventCreateKeyboardEvent(_NJHIDSource(), kVK_Control, NO);
            CGEventSetType(flagUp, kCGEventFlagsChanged);
            CGEventSetFlags(flagUp, 0);
            CGEventPost(kCGHIDEventTap, flagUp);
            CFRelease(flagUp);
            break;
        }

        case NJSystemActionMoveRightSpace: {
            CGEventRef flagDown = CGEventCreateKeyboardEvent(_NJHIDSource(), kVK_Control, YES);
            CGEventSetType(flagDown, kCGEventFlagsChanged);
            CGEventSetFlags(flagDown, kCGEventFlagMaskControl);
            CGEventPost(kCGHIDEventTap, flagDown);
            CFRelease(flagDown);

            _RunAppleScript(@"tell application \"System Events\" to key code 124 using control down");

            CGEventRef flagUp = CGEventCreateKeyboardEvent(_NJHIDSource(), kVK_Control, NO);
            CGEventSetType(flagUp, kCGEventFlagsChanged);
            CGEventSetFlags(flagUp, 0);
            CGEventPost(kCGHIDEventTap, flagUp);
            CFRelease(flagUp);
            break;
        }
    }
}

- (void)untrigger {
    // System actions are fire-and-forget, no release needed.
}

@end
