//
//  NJOutputSystemAction.m
//  Enjoyable
//
//  Triggers macOS system-level actions via NSTask + osascript.
//  Uses System Events "key code" to simulate the default keyboard shortcuts.
//  This approach is thread-safe (unlike NSAppleScript) and bypasses CGEvent
//  limitations for system-level shortcuts.
//

#import <Cocoa/Cocoa.h>
#import "NJOutputSystemAction.h"

// Run osascript asynchronously via NSTask (thread-safe, fire-and-forget).
static void _RunOsascript(NSString *scriptSource) {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
    task.arguments = @[@"-e", scriptSource];
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];
    NSError *err = nil;
    [task launchAndReturnError:&err];
    if (err) {
        NSLog(@"NJOutputSystemAction: osascript failed: %@", err);
    }
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
    switch (_action) {
        case NJSystemActionMissionControl:
            // Ctrl+Up Arrow (key code 126 = kVK_UpArrow)
            _RunOsascript(@"tell application \"System Events\" to key code 126 using control down");
            break;

        case NJSystemActionAppExpose:
            // Ctrl+Down Arrow (key code 125 = kVK_DownArrow)
            _RunOsascript(@"tell application \"System Events\" to key code 125 using control down");
            break;

        case NJSystemActionShowDesktop:
            // F11 (key code 103 = kVK_F11, default "Show Desktop" shortcut)
            _RunOsascript(@"tell application \"System Events\" to key code 103");
            break;

        case NJSystemActionLaunchpad:
            // Open Launchpad via NSWorkspace (most reliable)
            [[NSWorkspace sharedWorkspace] openURL:
                [NSURL fileURLWithPath:@"/System/Applications/Launchpad.app"]];
            break;

        case NJSystemActionMoveLeftSpace:
            // Ctrl+Left Arrow (key code 123 = kVK_LeftArrow)
            _RunOsascript(@"tell application \"System Events\" to key code 123 using control down");
            break;

        case NJSystemActionMoveRightSpace:
            // Ctrl+Right Arrow (key code 124 = kVK_RightArrow)
            _RunOsascript(@"tell application \"System Events\" to key code 124 using control down");
            break;
    }
}

- (void)untrigger {
    // System actions are fire-and-forget.
}

@end
