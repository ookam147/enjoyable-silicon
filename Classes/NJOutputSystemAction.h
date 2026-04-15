//
//  NJOutputSystemAction.h
//  Enjoyable
//
//  Triggers macOS system-level actions (Mission Control, Launchpad, etc.)
//  that cannot be reached via CGEvent keyboard simulation.
//

#import "NJOutput.h"

typedef NS_ENUM(NSInteger, NJSystemAction) {
    NJSystemActionMissionControl = 0,
    NJSystemActionAppExpose,
    NJSystemActionShowDesktop,
    NJSystemActionLaunchpad,
    NJSystemActionMoveLeftSpace,
    NJSystemActionMoveRightSpace,
};

@interface NJOutputSystemAction : NJOutput

@property (nonatomic, assign) NJSystemAction action;

+ (NSArray<NSString *> *)actionTitles;

@end
