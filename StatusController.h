//
//  StatusController.h
//  Shortcuts

#import <Cocoa/Cocoa.h>

@interface StatusController : NSObject<NSMenuDelegate>
{
    IBOutlet NSButton *mLoginButton;
    IBOutlet NSTextField *mLoginText;
    IBOutlet NSButton *mObserverButton;
    IBOutlet NSTextField *mObserverText;
	IBOutlet NSPopUpButton *mBezelPopup;
	BOOL mIsObserverRunning;
	BOOL mIsAddedToLoginItems;
}

@property(strong) NSURL *observerURL;

- (IBAction)startOrStopObserver:(id)sender;
- (IBAction)addOrRemoveLoginItem:(id)sender;
- (IBAction)reviewSystemPrefsAccessibility:(id)sender;

- (void)observerStatusChanged;
- (void)loginItemsStatusChanged;

- (BOOL)isObserverRunning;
- (void)startShortcutObserver;
- (void)quitShortcutObserver;

- (void)populateBezelImageMenu:(NSMenu *)menu;
- (IBAction)bezelMenuItemSelected:(id)sender;

@end
