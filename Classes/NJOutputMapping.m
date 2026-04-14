//
//  NJOutputMapping.m
//  Enjoy
//
//  Created by Sam McCall on 6/05/09.
//

#import "NJOutputMapping.h"

#import "EnjoyableApplicationDelegate.h"
#import "NJMapping.h"
#import "NJInputController.h"

@implementation NJOutputMapping {
    NJMapping *_previousMapping;
}

+ (NSString *)serializationCode {
    return @"mapping";
}

- (NSDictionary *)serialize {
    NSString *name = _mapping ? _mapping.name : self.mappingName;
    if (!name)
        return nil;
    NSString *modeStr = (_switchMode == NJMappingSwitchModeMomentary) ? @"momentary" : @"toggle";
    return @{ @"type": self.class.serializationCode,
              @"name": name,
              @"switchMode": modeStr };
}

+ (NJOutputMapping *)outputWithSerialization:(NSDictionary *)serialization {
    NSString *name = serialization[@"name"];
    NJOutputMapping *output = [[NJOutputMapping alloc] init];
    output.mappingName = name;
    // Backwards compatible: missing switchMode defaults to toggle
    NSString *modeStr = serialization[@"switchMode"];
    if ([modeStr isEqualToString:@"momentary"])
        output.switchMode = NJMappingSwitchModeMomentary;
    else
        output.switchMode = NJMappingSwitchModeToggle;
    return name ? output : nil;
}

- (void)trigger {
    EnjoyableApplicationDelegate *ctrl = (EnjoyableApplicationDelegate *)NSApplication.sharedApplication.delegate;
    if (!_mapping) {
        return;
    }

    switch (_switchMode) {
        case NJMappingSwitchModeToggle:
            // Toggle: simply switch to target mapping
            [ctrl.ic activateMapping:_mapping];
            self.mappingName = _mapping.name;
            break;

        case NJMappingSwitchModeMomentary:
            // Momentary: remember current mapping, switch to target
            _previousMapping = ctrl.ic.currentMapping;
            [ctrl.ic activateMapping:_mapping];
            self.mappingName = _mapping.name;
            break;
    }
}

- (void)untrigger {
    if (_switchMode == NJMappingSwitchModeMomentary && _previousMapping) {
        // Option B: request deferred switch back — waits for all other
        // active outputs to release before actually switching.
        EnjoyableApplicationDelegate *ctrl = (EnjoyableApplicationDelegate *)NSApplication.sharedApplication.delegate;
        [ctrl.ic requestDeferredSwitchBackToMapping:_previousMapping];
        _previousMapping = nil;
    }
}

- (void)postLoadProcess:(id <NSFastEnumeration>)allMappings {
    if (!self.mapping) {
        for (NJMapping *mapping in allMappings) {
            if ([mapping.name isEqualToString:self.mappingName]) {
                self.mapping = mapping;
                break;
            }
        }
    }
}

@end
