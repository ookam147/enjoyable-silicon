//
//  NJOutputKeyCombination.h
//  Enjoyable
//
//  System-level key combination output. Supports up to 4 modifier
//  keys (⌘⇧⌥⌃) plus one main key, with proper CGEvent ordering.
//

#import "NJOutput.h"

@interface NJOutputKeyCombination : NJOutput

@property (nonatomic, assign) CGKeyCode keyCode;           // Main key
@property (nonatomic, assign) CGEventFlags modifierFlags;   // Modifier bitmask
@property (nonatomic, assign) BOOL repeatEnabled;           // Default YES

@end
