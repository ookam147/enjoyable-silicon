//
//  NJOutputKeyPress.m
//  Enjoy
//
//  Created by Sam McCall on 5/05/09.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Carbon/Carbon.h>

#import "NJOutputKeyPress.h"
#import "NJKeyInputField.h"
#import "NJKeyRepeatManager.h"

// Use HID system state source so events are visible to system-level
// shortcut handlers (Mission Control, App Exposé, etc.).
static CGEventSourceRef _NJHIDSource(void) {
    static CGEventSourceRef source;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    });
    return source;
}

#pragma mark - Modifier key detection

static BOOL _IsModifierKey(CGKeyCode keyCode) {
    return keyCode == kVK_Shift || keyCode == kVK_RightShift
        || keyCode == kVK_Control || keyCode == kVK_RightControl
        || keyCode == kVK_Option || keyCode == kVK_RightOption
        || keyCode == kVK_Command || keyCode == kVK_RightCommand;
}

static CGEventFlags _ModifierFlagForKeyCode(CGKeyCode keyCode) {
    switch (keyCode) {
        case kVK_Shift: case kVK_RightShift:     return kCGEventFlagMaskShift;
        case kVK_Control: case kVK_RightControl:  return kCGEventFlagMaskControl;
        case kVK_Option: case kVK_RightOption:    return kCGEventFlagMaskAlternate;
        case kVK_Command: case kVK_RightCommand:  return kCGEventFlagMaskCommand;
        default: return 0;
    }
}

@implementation NJOutputKeyPress {
    NJKeyRepeatManager *_repeatManager;
}

- (instancetype)init {
    if ((self = [super init])) {
        _repeatEnabled = YES; // default: repeat enabled
    }
    return self;
}

+ (NSString *)serializationCode {
    return @"key press";
}

- (NSDictionary *)serialize {
    if (_keyCode == NJKeyInputFieldEmpty)
        return nil;
    return @{ @"type": self.class.serializationCode,
              @"key": @(_keyCode),
              @"repeat": @(_repeatEnabled) };
}

+ (NJOutput *)outputWithSerialization:(NSDictionary *)serialization {
    NJOutputKeyPress *output = [[NJOutputKeyPress alloc] init];
    output.keyCode = [serialization[@"key"] unsignedShortValue];
    // Backwards compatible: if "repeat" key is missing, default to YES
    NSNumber *repeat = serialization[@"repeat"];
    output.repeatEnabled = repeat ? [repeat boolValue] : YES;
    return output;
}

#pragma mark - Key send

- (void)_sendKeyDown {
    CGEventRef keyDown = CGEventCreateKeyboardEvent(_NJHIDSource(), _keyCode, YES);
    CGEventPost(kCGHIDEventTap, keyDown);
    CFRelease(keyDown);
}

- (void)_sendKeyUp {
    CGEventRef keyUp = CGEventCreateKeyboardEvent(_NJHIDSource(), _keyCode, NO);
    CGEventPost(kCGHIDEventTap, keyUp);
    CFRelease(keyUp);

    // Safety net for modifier keys: verify the modifier was actually cleared
    // from HID state after keyUp. If macOS or a system service (e.g. Dictation)
    // restored it, force-clear via kCGEventFlagsChanged with flags=0.
    if (_IsModifierKey(_keyCode)) {
        CGEventFlags currentFlags = CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState);
        CGEventFlags targetFlag = _ModifierFlagForKeyCode(_keyCode);
        if (currentFlags & targetFlag) {
            CGEventRef clearEvent = CGEventCreateKeyboardEvent(_NJHIDSource(), _keyCode, NO);
            CGEventSetType(clearEvent, kCGEventFlagsChanged);
            CGEventSetFlags(clearEvent, 0);
            CGEventPost(kCGHIDEventTap, clearEvent);
            CFRelease(clearEvent);
            NSLog(@"[NJOutputKeyPress] Force-cleared residual modifier flag 0x%llx for key %d",
                  (unsigned long long)targetFlag, _keyCode);
        }
    }
}

#pragma mark - Trigger / Untrigger

- (void)trigger {
    if (_keyCode == NJKeyInputFieldEmpty)
        return;

    // Send the initial key down event immediately
    [self _sendKeyDown];

    // Start repeat timer ONLY for non-modifier keys.
    // Physical keyboards suppress modifier key repeat; we must do the same.
    // Without this, holding a mapped modifier key sends a kCGEventFlagsChanged
    // every ~90ms, which can confuse system services (e.g. Dictation).
    if (_repeatEnabled && !_IsModifierKey(_keyCode)) {
        if (!_repeatManager)
            _repeatManager = [[NJKeyRepeatManager alloc] init];
        __weak __typeof(self) weakSelf = self;
        [_repeatManager startRepeatingWithBlock:^{
            [weakSelf _sendKeyDown];
        }];
    }
}

- (void)untrigger {
    // Stop repeating first
    [_repeatManager stopRepeating];

    if (_keyCode != NJKeyInputFieldEmpty) {
        [self _sendKeyUp];
    }
}

@end
