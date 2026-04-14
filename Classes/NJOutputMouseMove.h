//
//  NJOutputMouseMove.h
//  Enjoy
//
//  Created by Yifeng Huang on 7/26/12.
//

#import "NJOutput.h"

@interface NJOutputMouseMove : NJOutput

@property (nonatomic, assign) int axis;
@property (nonatomic, assign) float speed;
@property (nonatomic, assign) float exponent;      // Acceleration curve power (default 2.0)
@property (nonatomic, assign) float inputDeadzone;  // Input deadzone threshold (default 0.08)
@property (nonatomic, assign) BOOL set;
@property (nonatomic, assign) BOOL inDeadZone;
@end
