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

    // Lazy resolution: if the mapping reference was lost (e.g. after a rename
    // or the target was removed and recreated), try to find it by name.
    if (!_mapping && self.mappingName) {
        for (NJMapping *m in ctrl.ic.mappings) {
            if ([m.name isEqualToString:self.mappingName]) {
                self.mapping = m;
                NSLog(@"[NJOutputMapping] Lazy-resolved mapping '%@'", self.mappingName);
                break;
            }
        }
    }

    if (!_mapping) {
        NSLog(@"[NJOutputMapping] Cannot trigger: mapping reference is nil for target '%@'",
              self.mappingName ?: @"(unknown)");
        return;
    }

    switch (_switchMode) {
        case NJMappingSwitchModeToggle:
            [ctrl.ic activateMapping:_mapping];
            self.mappingName = _mapping.name;
            break;

        case NJMappingSwitchModeMomentary:
            _previousMapping = ctrl.ic.currentMapping;
            [ctrl.ic activateMappingForcibly:_mapping];
            self.mappingName = _mapping.name;
            break;
    }
}

- (void)untrigger {
    // Lazy resolution (same as trigger)
    if (!_mapping && self.mappingName) {
        EnjoyableApplicationDelegate *ctrl = (EnjoyableApplicationDelegate *)NSApplication.sharedApplication.delegate;
        for (NJMapping *m in ctrl.ic.mappings) {
            if ([m.name isEqualToString:self.mappingName]) {
                self.mapping = m;
                break;
            }
        }
    }

    if (_switchMode == NJMappingSwitchModeMomentary && _previousMapping) {
        EnjoyableApplicationDelegate *ctrl = (EnjoyableApplicationDelegate *)NSApplication.sharedApplication.delegate;
        [ctrl.ic activateMappingForcibly:_previousMapping];
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
