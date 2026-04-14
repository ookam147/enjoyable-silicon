//
//  NJOutputKeyCombination.m
//  Enjoyable
//
//  Sends a key combination (modifier keys + main key) via CGEvent.
//  Uses kCGEventFlagsChanged to update global modifier state (not individual
//  modifier keyDown events), then sends the main key with flags set.
//  This is the correct way to simulate system-level shortcuts on macOS.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Carbon/Carbon.h>

#import "NJOutputKeyCombination.h"
#import "NJKeyInputField.h"
#import "NJKeyRepeatManager.h"

// Map from CGEventFlags bitmask to virtual key codes for individual modifiers.
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

#pragma mark - Modifier state via kCGEventFlagsChanged

// Send kCGEventFlagsChanged events to update global modifier state.
// Each event carries the CUMULATIVE flags, building up from zero.
- (void)_pressModifiers {
    CGEventFlags cumulative = 0;
    for (int i = 0; i < kModifierCount; i++) {
        if (_modifierFlags & kModifiers[i].flag) {
            cumulative |= kModifiers[i].flag;
            CGEventRef flagEvent = CGEventCreateKeyboardEvent(NULL, kModifiers[i].keyCode, YES);
            CGEventSetType(flagEvent, kCGEventFlagsChanged);
            CGEventSetFlags(flagEvent, cumulative);
            CGEventPost(kCGHIDEventTap, flagEvent);
            CFRelease(flagEvent);
        }
    }
}

// Release modifiers by sending kCGEventFlagsChanged with cumulative
// flags DECREASING (reverse order).
- (void)_releaseModifiers {
    CGEventFlags cumulative = _modifierFlags;
    for (int i = kModifierCount - 1; i >= 0; i--) {
        if (_modifierFlags & kModifiers[i].flag) {
            cumulative &= ~kModifiers[i].flag;
            CGEventRef flagEvent = CGEventCreateKeyboardEvent(NULL, kModifiers[i].keyCode, NO);
            CGEventSetType(flagEvent, kCGEventFlagsChanged);
            CGEventSetFlags(flagEvent, cumulative);
            CGEventPost(kCGHIDEventTap, flagEvent);
            CFRelease(flagEvent);
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

- (void)_sendMainKeyTap {
    [self _sendMainKeyDown];
    [self _sendMainKeyUp];
}

#pragma mark - Trigger / Untrigger

- (void)trigger {
    if (_keyCode == NJKeyInputFieldEmpty)
        return;

    // 1. Update global modifier state via flagsChanged events
    [self _pressModifiers];

    // 2. Send main key down with modifier flags
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
    [_repeatManager stopRepeating];

    if (_keyCode == NJKeyInputFieldEmpty)
        return;

    // Release in correct order: main key up, then clear modifier state
    [self _sendMainKeyUp];
    [self _releaseModifiers];
}

@end
