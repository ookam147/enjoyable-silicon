//
//  NJInputAnalog.m
//  Enjoy
//
//  Created by Sam McCall on 5/05/09.
//

#import "NJInputAnalog.h"

static float normalize(CFIndex p, CFIndex min, CFIndex max) {
    return 2 * (p - min) / (float)(max - min) - 1;
}

// Re-normalize value after deadzone filtering to eliminate the
// "jump" from 0 to deadzone threshold. Maps [deadzone, 1.0] → [0, 1.0].
static float applyDeadzone(float value, float deadzone) {
    float absVal = fabsf(value);
    if (absVal < deadzone)
        return 0.0f;
    float sign = (value > 0) ? 1.0f : -1.0f;
    return sign * (absVal - deadzone) / (1.0f - deadzone);
}

@implementation NJInputAnalog {
    CFIndex _rawMin;
    CFIndex _rawMax;
}

// deadZone is now a public @property (declared in .h)
// Default set in init below.

- (id)initWithElement:(IOHIDElementRef)element
                index:(int)index
               parent:(NJInputPathElement *)parent
{
    if ((self = [super initWithName:NJINPUT_NAME(NSLocalizedString(@"axis %d", @"axis name"), index)
                                eid:NJINPUT_EID("Axis", index)
                            element:element
                             parent:parent])) {
        self.children = @[[[NJInput alloc] initWithName:NSLocalizedString(@"axis low", @"axis low trigger")
                                                    eid:@"Low"
                                                   parent:self],
                          [[NJInput alloc] initWithName:NSLocalizedString(@"axis high", @"axis high trigger")
                                                    eid:@"High"
                                                   parent:self]];
        _rawMax = IOHIDElementGetPhysicalMax(element);
        _rawMin = IOHIDElementGetPhysicalMin(element);
        _deadZone = 0.08f; // 8% deadzone, suitable for Xbox controllers
    }
    return self;
}

- (id)findSubInputForValue:(IOHIDValueRef)value {
    float mag = normalize(IOHIDValueGetIntegerValue(value), _rawMin, _rawMax);
    if (mag < -_deadZone)
        return self.children[0];
    else if (mag > _deadZone)
        return self.children[1];
    else
        return nil;
}

- (void)notifyEvent:(IOHIDValueRef)value {
    float rawMagnitude = normalize(IOHIDValueGetIntegerValue(value), _rawMin, _rawMax);
    // Apply deadzone with re-normalization to eliminate jump at threshold
    float magnitude = applyDeadzone(rawMagnitude, _deadZone);
    self.magnitude = magnitude;

    [self.children[0] setMagnitude:fabsf(MIN(magnitude, 0))];
    [self.children[1] setMagnitude:fabsf(MAX(magnitude, 0))];
    [self.children[0] setActive:magnitude < 0];
    [self.children[1] setActive:magnitude > 0];
}

@end
