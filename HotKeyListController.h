//
//  HotKeyListController.h
//  Shortcuts

#import <Cocoa/Cocoa.h>
#import "ShortcutsController.h"

@interface HotKeyListController : NSObject
{
    IBOutlet NSTableView *	mShortcutTableView;
    IBOutlet NSButton *		mEditButton;
    IBOutlet NSButton *		mRemoveButton;

	IBOutlet ShortcutsController *	mShortcutsController;
}

- (IBAction)editShortcut:(id)sender;
- (IBAction)removeShortcut:(id)sender;


@end
