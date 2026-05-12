//
//  NJOutputMouseScroll.m
//  Enjoy
//
//  Created by Yifeng Huang on 7/28/12.
//

#import <CoreGraphics/CoreGraphics.h>
#import "NJOutputMouseScroll.h"

// Private event source so scroll events are distinguishable from
// real hardware events. Tools like iScroll/Scroll Reverser that use
// CGEventTap can inspect the source to skip software-generated events.
static CGEventSourceRef _NJScrollSource(void) {
    static CGEventSourceRef source;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    });
    return source;
}

@implementation NJOutputMouseScroll

+ (NSString *)serializationCode {
    return @"mouse scroll";
}

- (NSDictionary *)serialize {
    return @{ @"type": self.class.serializationCode,
              @"direction": @(_direction),
              @"speed": @(_speed),
              @"smooth": @(_smooth),
              };
}

+ (NJOutput *)outputWithSerialization:(NSDictionary *)serialization {
    NJOutputMouseScroll *output = [[NJOutputMouseScroll alloc] init];
    output.direction = [serialization[@"direction"] intValue];
    output.speed = [serialization[@"speed"] floatValue];
    output.smooth = [serialization[@"smooth"] boolValue];
    return output;
}

- (BOOL)isContinuous {
    return _smooth;
}

- (int)wheel:(int)n {
    int amount =  abs(_direction) == n ? _direction / n : 0;
    if (self.smooth)
        amount *= (int)(_speed * self.magnitude);
    return amount;
}

- (void)trigger {
    if (!_smooth) {
        CGEventRef scroll = CGEventCreateScrollWheelEvent(_NJScrollSource(),
                                                          kCGScrollEventUnitLine,
                                                          2,
                                                           [self wheel:1],
                                                           [self wheel:2]);
        CGEventSetFlags(scroll, 0);
        // Post to session tap to bypass HID-level event taps (e.g. iScroll)
        CGEventPost(kCGSessionEventTap, scroll);
        CFRelease(scroll);
    }
}

- (BOOL)update:(NJInputController *)ic {
    if (self.magnitude < 0.05f)
        return NO; // dead zone
    
    CGEventRef scroll = CGEventCreateScrollWheelEvent(_NJScrollSource(),
                                                      kCGScrollEventUnitPixel,
                                                      2,
                                                       [self wheel:1],
                                                       [self wheel:2]);
    CGEventSetFlags(scroll, 0);
    // Post to session tap to bypass HID-level event taps (e.g. iScroll)
    CGEventPost(kCGSessionEventTap, scroll);
    CFRelease(scroll);

    return YES;
}

@end
