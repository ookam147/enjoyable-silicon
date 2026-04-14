//
//  NJOutputKeyPress.m
//  Enjoy
//
//  Created by Sam McCall on 5/05/09.
//

#import <CoreGraphics/CoreGraphics.h>

#import "NJOutputKeyPress.h"
#import "NJKeyInputField.h"
#import "NJKeyRepeatManager.h"

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

- (void)_sendKeyDown {
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, _keyCode, YES);
    CGEventPost(kCGHIDEventTap, keyDown);
    CFRelease(keyDown);
}

- (void)trigger {
    if (_keyCode == NJKeyInputFieldEmpty)
        return;

    // Send the initial key down event immediately
    [self _sendKeyDown];

    // Start repeat timer if enabled
    if (_repeatEnabled) {
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
        CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, _keyCode, NO);
        CGEventPost(kCGHIDEventTap, keyUp);
        CFRelease(keyUp);
    }
}

@end
