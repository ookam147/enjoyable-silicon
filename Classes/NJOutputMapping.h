//
//  NJOutputMapping.h
//  Enjoy
//
//  Created by Sam McCall on 6/05/09.
//  Copyright 2009 University of Otago. All rights reserved.
//

#import "NJOutput.h"

@class NJMapping;

typedef NS_ENUM(NSInteger, NJMappingSwitchMode) {
    NJMappingSwitchModeToggle,    // Click to switch, click again to switch back
    NJMappingSwitchModeMomentary, // Hold to stay, release to revert
};

@interface NJOutputMapping : NJOutput

@property (nonatomic, weak) NJMapping *mapping;
@property (nonatomic, copy) NSString *mappingName;
@property (nonatomic, assign) NJMappingSwitchMode switchMode;

@end
