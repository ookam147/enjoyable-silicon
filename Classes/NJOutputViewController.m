//
//  NJOutputController.m
//  Enjoy
//
//  Created by Sam McCall on 5/05/09.
//

#import <Cocoa/Cocoa.h>
#import "NJOutputViewController.h"

#import "NJMapping.h"
#import "NJInput.h"
#import "NJEvents.h"
#import "NJInputController.h"
#import "NJKeyInputField.h"
#import "NJOutputMapping.h"
#import "NJOutputViewController.h"
#import "NJOutputKeyPress.h"
#import "NJOutputKeyCombination.h"
#import "NJOutputMouseButton.h"
#import "NJOutputMouseMove.h"
#import "NJOutputMouseScroll.h"
#import "NSView+FirstResponder.h"
#import "NSMenu+RepresentedObjectAccessors.h"

typedef NS_ENUM(NSUInteger, NJOutputRow) {
    NJOutputRowNone,
    NJOutputRowKey,
    NJOutputRowSwitch,
    NJOutputRowMove,
    NJOutputRowButton,
    NJOutputRowScroll,
    NJOutputRowKeyCombination,
};

@implementation NJOutputViewController {
    NJInput *_input;
    BOOL _dynamicUICreated;
}

- (id)init {
    if ((self = [super init])) {
        [NSNotificationCenter.defaultCenter
            addObserver:self
            selector:@selector(mappingListDidChange:)
            name:NJEventMappingListChanged
            object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Dynamic UI Creation

- (void)_createDynamicUI {
    if (_dynamicUICreated)
        return;
    _dynamicUICreated = YES;

    // --- Add "Key combination:" radio button row to the matrix ---
    NSInteger rowCount = self.radioButtons.numberOfRows;
    [self.radioButtons addRow];
    NSButtonCell *comboCell = [self.radioButtons cellAtRow:rowCount column:0];
    comboCell.title = @"Key combination:";
    comboCell.enabled = NO;

    // --- Key combination UI: modifier checkboxes + key input ---
    // Position relative to the radio buttons matrix
    NSView *parentView = self.radioButtons.superview;
    CGFloat baseX = 191; // Same X as existing key input
    CGFloat comboY = -6; // Below the scroll controls, near bottom

    // Modifier checkboxes in a horizontal row
    NSArray *modLabels = @[@"⌃", @"⌥", @"⇧", @"⌘"];
    NSArray *modProps = @[@"modifierControl", @"modifierOption", @"modifierShift", @"modifierCommand"];
    CGFloat checkX = baseX;
    for (int i = 0; i < 4; i++) {
        NSButton *check = [NSButton checkboxWithTitle:modLabels[i] target:self action:@selector(_comboModifierChanged:)];
        check.frame = NSMakeRect(checkX, comboY, 42, 18);
        check.font = [NSFont systemFontOfSize:13];
        [parentView addSubview:check];
        [self setValue:check forKey:modProps[i]];
        checkX += 42;
    }

    // Key input field for the main key
    self.comboKeyInput = [[NJKeyInputField alloc] initWithFrame:NSMakeRect(baseX, comboY - 24, 170, 22)];
    self.comboKeyInput.delegate = self;
    [parentView addSubview:self.comboKeyInput];

    // --- Mapping switch mode selector (Phase 4) ---
    self.mappingSwitchModeSelect = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(baseX, 137, 170, 20)];
    self.mappingSwitchModeSelect.segmentCount = 2;
    [self.mappingSwitchModeSelect setLabel:@"Toggle" forSegment:0];
    [self.mappingSwitchModeSelect setLabel:@"Momentary" forSegment:1];
    self.mappingSwitchModeSelect.selectedSegment = 0;
    [self.mappingSwitchModeSelect setControlSize:NSControlSizeSmall];
    self.mappingSwitchModeSelect.target = self;
    self.mappingSwitchModeSelect.action = @selector(_mappingSwitchModeChanged:);
    [parentView addSubview:self.mappingSwitchModeSelect];
}

- (void)_comboModifierChanged:(NSButton *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowKeyCombination column:0];
    [self commit];
}

- (void)_mappingSwitchModeChanged:(NSSegmentedControl *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowSwitch column:0];
    [self commit];
}

#pragma mark - Interface Cleanup

- (void)cleanUpInterface {
    [self _createDynamicUI];
    NSInteger row = self.radioButtons.selectedRow;
    
    if (row != NJOutputRowKey) {
        self.keyInput.keyCode = NJKeyInputFieldEmpty;
        [self.keyInput resignIfFirstResponder];
    }
    
    if (row != NJOutputRowSwitch) {
        [self.mappingPopup selectItemAtIndex:-1];
        [self.mappingPopup resignIfFirstResponder];
        self.unknownMapping.hidden = YES;
        self.mappingSwitchModeSelect.hidden = YES;
    } else {
        self.mappingSwitchModeSelect.hidden = NO;
    }
    
    if (row != NJOutputRowMove) {
        self.mouseDirSelect.selectedSegment = -1;
        self.mouseSpeedSlider.doubleValue = self.mouseSpeedSlider.minValue;
        self.setCheck.state = NSControlStateValueOff;
        [self.setCheck resignIfFirstResponder];
        [self.mouseDirSelect resignIfFirstResponder];
    } else {
        if (self.mouseDirSelect.selectedSegment == -1)
            self.mouseDirSelect.selectedSegment = 0;
        if (self.mouseSpeedSlider.floatValue == 0)
            self.mouseSpeedSlider.floatValue = 10;
    }
    
    if (row != NJOutputRowButton) {
        self.mouseBtnSelect.selectedSegment = -1;
        [self.mouseBtnSelect resignIfFirstResponder];
    } else if (self.mouseBtnSelect.selectedSegment == -1)
        self.mouseBtnSelect.selectedSegment = 0;
    
    if (row != NJOutputRowScroll) {
        self.scrollDirSelect.selectedSegment = -1;
        self.scrollSpeedSlider.doubleValue = self.scrollSpeedSlider.minValue;
        self.smoothCheck.state = NSControlStateValueOff;
        [self.scrollDirSelect resignIfFirstResponder];
        [self.scrollSpeedSlider resignIfFirstResponder];
        [self.smoothCheck resignIfFirstResponder];
    } else {
        if (self.scrollDirSelect.selectedSegment == -1)
            self.scrollDirSelect.selectedSegment = 0;
    }

    if (row != NJOutputRowKeyCombination) {
        self.comboKeyInput.keyCode = NJKeyInputFieldEmpty;
        [self.comboKeyInput resignIfFirstResponder];
        self.modifierCommand.state = NSControlStateValueOff;
        self.modifierShift.state = NSControlStateValueOff;
        self.modifierOption.state = NSControlStateValueOff;
        self.modifierControl.state = NSControlStateValueOff;
        self.comboKeyInput.hidden = YES;
        self.modifierCommand.hidden = YES;
        self.modifierShift.hidden = YES;
        self.modifierOption.hidden = YES;
        self.modifierControl.hidden = YES;
    } else {
        self.comboKeyInput.hidden = NO;
        self.modifierCommand.hidden = NO;
        self.modifierShift.hidden = NO;
        self.modifierOption.hidden = NO;
        self.modifierControl.hidden = NO;
    }
}

#pragma mark - Actions

- (IBAction)outputTypeChanged:(NSView *)sender {
    [sender.window makeFirstResponder:sender];
    if (self.radioButtons.selectedRow == NJOutputRowKey)
        [self.keyInput.window makeFirstResponder:self.keyInput];
    else if (self.radioButtons.selectedRow == NJOutputRowKeyCombination)
        [self.comboKeyInput.window makeFirstResponder:self.comboKeyInput];
    [self commit];
}

- (void)keyInputField:(NJKeyInputField *)keyInput didChangeKey:(CGKeyCode)keyCode {
    if (keyInput == self.keyInput) {
        [self.radioButtons selectCellAtRow:NJOutputRowKey column:0];
    } else if (keyInput == self.comboKeyInput) {
        [self.radioButtons selectCellAtRow:NJOutputRowKeyCombination column:0];
    }
    [self.radioButtons.window makeFirstResponder:self.radioButtons];
    [self commit];
}

- (void)keyInputFieldDidClear:(NJKeyInputField *)keyInput {
    if (keyInput == self.keyInput) {
        [self.radioButtons selectCellAtRow:NJOutputRowNone column:0];
    } else if (keyInput == self.comboKeyInput) {
        [self.radioButtons selectCellAtRow:NJOutputRowNone column:0];
    }
    [self commit];
}

- (void)mappingChosen:(id)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowSwitch column:0];
    [self.mappingPopup.window makeFirstResponder:self.mappingPopup];
    self.unknownMapping.hidden = YES;
    [self commit];
}

- (void)mouseDirectionChanged:(NSView *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowMove column:0];
    [sender.window makeFirstResponder:sender];
    [self commit];
}

- (void)mouseTypeChanged:(NSButton *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowMove column:0];
    [sender.window makeFirstResponder:sender];
    [self commit];
}

- (void)mouseSpeedChanged:(NSSlider *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowMove column:0];
    [sender.window makeFirstResponder:sender];
    [self commit];
}

- (void)mouseButtonChanged:(NSView *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowButton column:0];
    [sender.window makeFirstResponder:sender];
    [self commit];
}

- (void)scrollDirectionChanged:(NSView *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowScroll column:0];
    [sender.window makeFirstResponder:sender];
    [self commit];
}

- (void)scrollSpeedChanged:(NSSlider *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowScroll column:0];
    [sender.window makeFirstResponder:sender];
    [self commit];
}

- (IBAction)scrollTypeChanged:(NSButton *)sender {
    [self.radioButtons selectCellAtRow:NJOutputRowScroll column:0];
    [sender.window makeFirstResponder:sender];
    if (sender.state == NSControlStateValueOn) {
        self.scrollSpeedSlider.doubleValue =
            self.scrollSpeedSlider.minValue
            + (self.scrollSpeedSlider.maxValue - self.scrollSpeedSlider.minValue) / 2;
        self.scrollSpeedSlider.enabled = YES;
    } else {
        self.scrollSpeedSlider.doubleValue = self.scrollSpeedSlider.minValue;
        self.scrollSpeedSlider.enabled = NO;
    }
    [self commit];
}

#pragma mark - Build current modifier flags from checkboxes

- (CGEventFlags)_currentModifierFlags {
    CGEventFlags flags = 0;
    if (self.modifierCommand.state == NSControlStateValueOn)
        flags |= kCGEventFlagMaskCommand;
    if (self.modifierShift.state == NSControlStateValueOn)
        flags |= kCGEventFlagMaskShift;
    if (self.modifierOption.state == NSControlStateValueOn)
        flags |= kCGEventFlagMaskAlternate;
    if (self.modifierControl.state == NSControlStateValueOn)
        flags |= kCGEventFlagMaskControl;
    return flags;
}

#pragma mark - Make Output

- (NJOutput *)makeOutput {
    switch (self.radioButtons.selectedRow) {
        case NJOutputRowNone:
            return nil;
        case NJOutputRowKey:
            if (self.keyInput.hasKeyCode) {
                NJOutputKeyPress *k = [[NJOutputKeyPress alloc] init];
                k.keyCode = self.keyInput.keyCode;
                return k;
            } else {
                return nil;
            }
            break;
        case NJOutputRowSwitch: {
            NJOutputMapping *c = [[NJOutputMapping alloc] init];
            c.mapping = [self.delegate outputViewController:self
                                            mappingForIndex:self.mappingPopup.indexOfSelectedItem];
            c.switchMode = (NJMappingSwitchMode)self.mappingSwitchModeSelect.selectedSegment;
            return c;
        }
        case NJOutputRowMove: {
            NJOutputMouseMove *mm = [[NJOutputMouseMove alloc] init];
            mm.axis = (int)self.mouseDirSelect.selectedSegment;
            mm.speed = self.mouseSpeedSlider.floatValue;
            mm.exponent = 2.0f;       // default curve
            mm.inputDeadzone = 0.08f;  // default deadzone
            mm.set = self.setCheck.state == NSControlStateValueOn;
            return mm;
        }
        case NJOutputRowButton: {
            NJOutputMouseButton *mb = [[NJOutputMouseButton alloc] init];
            mb.button = (uint32_t)[self.mouseBtnSelect.cell tagForSegment:self.mouseBtnSelect.selectedSegment];
            return mb;
        }
        case NJOutputRowScroll: {
            NJOutputMouseScroll *ms = [[NJOutputMouseScroll alloc] init];
            ms.direction = (int)[self.scrollDirSelect.cell tagForSegment:self.scrollDirSelect.selectedSegment];
            ms.speed = self.scrollSpeedSlider.floatValue;
            ms.smooth = self.smoothCheck.state == NSControlStateValueOn;
            return ms;
        }
        case NJOutputRowKeyCombination: {
            if (self.comboKeyInput.hasKeyCode) {
                NJOutputKeyCombination *kc = [[NJOutputKeyCombination alloc] init];
                kc.keyCode = self.comboKeyInput.keyCode;
                kc.modifierFlags = [self _currentModifierFlags];
                return kc;
            } else {
                return nil;
            }
        }
        default:
            return nil;
    }
}

- (void)commit {
    [self cleanUpInterface];
    [self.delegate outputViewController:self
                              setOutput:[self makeOutput]
                               forInput:_input];
}

- (BOOL)enabled {
    return self.radioButtons.isEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    [self _createDynamicUI];
    self.radioButtons.enabled = enabled;
    self.keyInput.enabled = enabled;
    self.mappingPopup.enabled = enabled;
    self.mouseDirSelect.enabled = enabled;
    self.mouseSpeedSlider.enabled = enabled;
    self.mouseBtnSelect.enabled = enabled;
    self.scrollDirSelect.enabled = enabled;
    self.smoothCheck.enabled = enabled;
    self.setCheck.enabled = enabled;
    self.scrollSpeedSlider.enabled = enabled && self.smoothCheck.state;
    self.comboKeyInput.enabled = enabled;
    self.modifierCommand.enabled = enabled;
    self.modifierShift.enabled = enabled;
    self.modifierOption.enabled = enabled;
    self.modifierControl.enabled = enabled;
    self.mappingSwitchModeSelect.enabled = enabled;
    if (!enabled)
        self.unknownMapping.hidden = YES;
}

- (void)loadOutput:(NJOutput *)output forInput:(NJInput *)input {
    [self _createDynamicUI];
    _input = input;
    if (!input) {
        [self setEnabled:NO];
        self.title.stringValue = @"";
    } else {
        [self setEnabled:YES];
        NSString *inpFullName = input.name;
        for (NJInputPathElement *cur = input.parent; cur; cur = cur.parent) {
            inpFullName = [[NSString alloc] initWithFormat:@"%@ ▸ %@", cur.name, inpFullName];
        }
        self.title.stringValue = inpFullName;
    }

    if ([output isKindOfClass:NJOutputKeyPress.class]) {
        [self.radioButtons selectCellAtRow:NJOutputRowKey column:0];
        self.keyInput.keyCode = [(NJOutputKeyPress*)output keyCode];
    } else if ([output isKindOfClass:NJOutputKeyCombination.class]) {
        NJOutputKeyCombination *combo = (NJOutputKeyCombination *)output;
        [self.radioButtons selectCellAtRow:NJOutputRowKeyCombination column:0];
        self.comboKeyInput.keyCode = combo.keyCode;
        CGEventFlags flags = combo.modifierFlags;
        self.modifierCommand.state = (flags & kCGEventFlagMaskCommand) ? NSControlStateValueOn : NSControlStateValueOff;
        self.modifierShift.state = (flags & kCGEventFlagMaskShift) ? NSControlStateValueOn : NSControlStateValueOff;
        self.modifierOption.state = (flags & kCGEventFlagMaskAlternate) ? NSControlStateValueOn : NSControlStateValueOff;
        self.modifierControl.state = (flags & kCGEventFlagMaskControl) ? NSControlStateValueOn : NSControlStateValueOff;
    } else if ([output isKindOfClass:NJOutputMapping.class]) {
        [self.radioButtons selectCellAtRow:NJOutputRowSwitch column:0];
        NSMenuItem *item = [self.mappingPopup itemWithIdenticalRepresentedObject:
                            [(NJOutputMapping *)output mapping]];
        [self.mappingPopup selectItem:item];
        self.unknownMapping.hidden = !!item;
        self.unknownMapping.title = [(NJOutputMapping *)output mappingName];
        self.mappingSwitchModeSelect.selectedSegment = [(NJOutputMapping *)output switchMode];
    }
    else if ([output isKindOfClass:NJOutputMouseMove.class]) {
        [self.radioButtons selectCellAtRow:NJOutputRowMove column:0];
        self.mouseDirSelect.selectedSegment = [(NJOutputMouseMove *)output axis];
        self.mouseSpeedSlider.floatValue = [(NJOutputMouseMove *)output speed];
        self.setCheck.state = [(NJOutputMouseMove *)output set] ? NSControlStateValueOn : NSControlStateValueOff;
    }
    else if ([output isKindOfClass:NJOutputMouseButton.class]) {
        [self.radioButtons selectCellAtRow:NJOutputRowButton column:0];
        [self.mouseBtnSelect selectSegmentWithTag:[(NJOutputMouseButton *)output button]];
    }
    else if ([output isKindOfClass:NJOutputMouseScroll.class]) {
        [self.radioButtons selectCellAtRow:NJOutputRowScroll column:0];
        int direction = [(NJOutputMouseScroll *)output direction];
        float speed = [(NJOutputMouseScroll *)output speed];
        BOOL smooth = [(NJOutputMouseScroll *)output smooth];
        [self.scrollDirSelect selectSegmentWithTag:direction];
        self.scrollSpeedSlider.floatValue = speed;
        self.smoothCheck.state = smooth ? NSControlStateValueOn : NSControlStateValueOff;
        self.scrollSpeedSlider.enabled = smooth;
    } else {
        [self.radioButtons selectCellAtRow:self.enabled ? 0 : -1 column:0];
    }
    [self cleanUpInterface];
}

- (void)focusKey {
    if (self.radioButtons.selectedRow <= 1)
        [self.keyInput.window makeFirstResponder:self.keyInput];
    else if (self.radioButtons.selectedRow == NJOutputRowKeyCombination)
        [self.comboKeyInput.window makeFirstResponder:self.comboKeyInput];
    else
        [self.keyInput resignIfFirstResponder];
}

- (void)mappingListDidChange:(NSNotification *)note {
    NSArray *mappings = note.userInfo[NJMappingListKey];
    NJMapping *current = self.mappingPopup.selectedItem.representedObject;
    [self.mappingPopup.menu removeAllItems];
    for (NJMapping *mapping in mappings) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:mapping.name
                                                      action:@selector(mappingChosen:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = mapping;
        [self.mappingPopup.menu addItem:item];
    }
    [self.mappingPopup selectItemWithIdenticalRepresentedObject:current];
}

@end
