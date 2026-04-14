//
//  NJOutputController.h
//  Enjoy
//
//  Created by Sam McCall on 5/05/09.
//  Copyright 2009 University of Otago. All rights reserved.
//

#import "NJKeyInputField.h"

@class NJInput;
@class NJOutput;
@class NJMapping;

@protocol NJOutputViewControllerDelegate;

@interface NJOutputViewController : NSObject <NJKeyInputFieldDelegate>

@property (nonatomic, strong) IBOutlet NJKeyInputField *keyInput;
@property (nonatomic, strong) IBOutlet NSMatrix *radioButtons;
@property (nonatomic, strong) IBOutlet NSSegmentedControl *mouseDirSelect;
@property (nonatomic, strong) IBOutlet NSSlider *mouseSpeedSlider;
@property (nonatomic, strong) IBOutlet NSSegmentedControl *mouseBtnSelect;
@property (nonatomic, strong) IBOutlet NSSegmentedControl *scrollDirSelect;
@property (nonatomic, strong) IBOutlet NSSlider *scrollSpeedSlider;
@property (nonatomic, strong) IBOutlet NSTextField *title;
@property (nonatomic, strong) IBOutlet NSPopUpButton *mappingPopup;
@property (nonatomic, strong) IBOutlet NSButton *smoothCheck;
@property (nonatomic, strong) IBOutlet NSButton *setCheck;
@property (nonatomic, strong) IBOutlet NSButton *unknownMapping;

// Dynamically created UI for key combination (Phase 3)
@property (nonatomic, strong) NJKeyInputField *comboKeyInput;
@property (nonatomic, strong) NSButton *modifierCommand;
@property (nonatomic, strong) NSButton *modifierShift;
@property (nonatomic, strong) NSButton *modifierOption;
@property (nonatomic, strong) NSButton *modifierControl;

// Dynamically created UI for mapping switch mode (Phase 4)
@property (nonatomic, strong) NSSegmentedControl *mappingSwitchModeSelect;

@property (nonatomic, weak) IBOutlet id <NJOutputViewControllerDelegate> delegate;

- (void)loadOutput:(NJOutput *)output forInput:(NJInput *)input;
- (void)focusKey;

- (IBAction)outputTypeChanged:(id)sender;
- (IBAction)mouseDirectionChanged:(id)sender;
- (IBAction)mouseButtonChanged:(id)sender;
- (IBAction)mouseTypeChanged:(id)sender;
- (IBAction)scrollDirectionChanged:(id)sender;
- (IBAction)mouseSpeedChanged:(id)sender;
- (IBAction)scrollSpeedChanged:(id)sender;
- (IBAction)scrollTypeChanged:(id)sender;

@end

@protocol NJOutputViewControllerDelegate

- (NJMapping *)outputViewController:(NJOutputViewController *)ovc
                    mappingForIndex:(NSInteger)index;
- (void)outputViewController:(NJOutputViewController *)ovc
                   setOutput:(NJOutput *)output
                    forInput:(NJInput *)input;

@end
