//
//  NJOutputKeyCombination.m
//  Enjoyable
//
//  Sends a key combination (modifier keys + main key) via CGEvent.
//  Strictly follows the OS modifier ordering convention:
//    Modifiers Down → Main Key Down → Main Key Up → Modifiers Up (reverse)
//
//  Repeat only re-fires the main key while holding modifiers steady.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Carbon/Carbon.h>

#import "NJOutputKeyCombination.h"
#import "NJKeyInputField.h"
#import "NJKeyRepeatManager.h"

// Map from CGEventFlags bitmask to virtual key codes for individual modifiers.
// Order: Command, Shift, Option, Control (pressed in this order, released in reverse).
typedef struct {
    CGEventFlags flag;
    CGKeyCode keyCode;
} NJModifierEntry;

static const NJModifierEntry kModifiers[4] = {
    { kCGEventFlagMaskControl,   kVK_Control },
    { kCGEventFlagMaskAlternate, kVK_Option  },
    { kCGEventFlagMaskShift,     kVK_Shift   },
    { kCGEventFlagMaskCommand,   kVK_Command },
};
static const int kModifierCount = 4;

@implementation NJOutputKeyCombination {
    NJKeyRepeatManager *_repeatManager;
}

- (instancetype)init {
    if ((self = [super init])) {
        _repeatEnabled = YES;
    }
    return self;
}

+ (NSString *)serializationCode {
    return @"key combination";
}

- (NSDictionary *)serialize {
    if (_keyCode == NJKeyInputFieldEmpty)
        return nil;
    return @{ @"type": self.class.serializationCode,
              @"key": @(_keyCode),
              @"modifiers": @((unsigned long long)_modifierFlags),
              @"repeat": @(_repeatEnabled) };
}

+ (NJOutput *)outputWithSerialization:(NSDictionary *)serialization {
    NJOutputKeyCombination *output = [[NJOutputKeyCombination alloc] init];
    output.keyCode = [serialization[@"key"] unsignedShortValue];
    output.modifierFlags = (CGEventFlags)[serialization[@"modifiers"] unsignedLongLongValue];
    NSNumber *repeat = serialization[@"repeat"];
    output.repeatEnabled = repeat ? [repeat boolValue] : YES;
    return output;
}

#pragma mark - Modifier key press/release helpers

- (void)_pressModifiers {
    for (int i = 0; i < kModifierCount; i++) {
        if (_modifierFlags & kModifiers[i].flag) {
            CGEventRef ev = CGEventCreateKeyboardEvent(NULL, kModifiers[i].keyCode, YES);
            CGEventPost(kCGHIDEventTap, ev);
            CFRelease(ev);
        }
    }
}

- (void)_releaseModifiers {
    // Release in reverse order
    for (int i = kModifierCount - 1; i >= 0; i--) {
        if (_modifierFlags & kModifiers[i].flag) {
            CGEventRef ev = CGEventCreateKeyboardEvent(NULL, kModifiers[i].keyCode, NO);
            CGEventPost(kCGHIDEventTap, ev);
            CFRelease(ev);
        }
    }
}

#pragma mark - Main key with modifier flags

- (void)_sendMainKeyDown {
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, _keyCode, YES);
    CGEventSetFlags(keyDown, _modifierFlags);
    CGEventPost(kCGHIDEventTap, keyDown);
    CFRelease(keyDown);
}

- (void)_sendMainKeyUp {
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, _keyCode, NO);
    CGEventSetFlags(keyUp, _modifierFlags);
    CGEventPost(kCGHIDEventTap, keyUp);
    CFRelease(keyUp);
}

// For repeat: only re-fire the main key (modifiers stay held)
- (void)_sendMainKeyTap {
    [self _sendMainKeyDown];
    [self _sendMainKeyUp];
}

#pragma mark - Trigger / Untrigger

- (void)trigger {
    if (_keyCode == NJKeyInputFieldEmpty)
        return;

    // 1. Press modifier keys
    [self _pressModifiers];

    // 2. Press main key
    [self _sendMainKeyDown];

    // 3. Start repeat if enabled (repeats main key only)
    if (_repeatEnabled) {
        if (!_repeatManager)
            _repeatManager = [[NJKeyRepeatManager alloc] init];
        __weak __typeof(self) weakSelf = self;
        [_repeatManager startRepeatingWithBlock:^{
            [weakSelf _sendMainKeyTap];
        }];
    }
}

- (void)untrigger {
    // Stop repeating
    [_repeatManager stopRepeating];

    if (_keyCode == NJKeyInputFieldEmpty)
        return;

    // Release in correct order: main key up, then modifiers up (reverse)
    [self _sendMainKeyUp];
    [self _releaseModifiers];
}

@end
