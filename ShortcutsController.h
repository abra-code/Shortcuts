/* ShortcutsController */

#import <Cocoa/Cocoa.h>
#include "PluginLoading.h"
#include "HotKeyWindow.h"

enum
{
	kHotKeyDialog_None,
	kHotKeyDialog_ForMenuItem,
	kHotKeyDialog_ForContextMenu
};

@interface ShortcutsController : NSObject<NSMenuDelegate>
{
    IBOutlet NSPopUpButton *mTextItemsPopup;
    IBOutlet NSPopUpButton *mFileItemsPopup;
    IBOutlet NSPopUpButton *mFolderItemsPopup;
	IBOutlet NSTextField *mTextContextField;
	IBOutlet NSTextField *mFileContextField;
	IBOutlet NSTextField *mFolderContextField;
	
//	IBOutlet NSButton *mChooseFileButt;
	IBOutlet NSWindow *mMainShortcutWindow;
	IBOutlet HotKeyWindow *mHotKeyDialog;
    IBOutlet NSTableView *	mShortcutTableView;

    IBOutlet NSButton *mFileMultipleSelection;
    IBOutlet NSButton *mFolderMultipleSelection;

	//in the Menu tab
	IBOutlet NSTextField *mContextMenuLongHotKey;
	IBOutlet NSTextField *mContextMenuShortHotKey;

	NSMenu *mTextItemsMenu;
	NSMenu *mFileItemsMenu;
	NSMenu *mFolderItemsMenu;

	CFMutableArrayRef mShortcutList;

	CFArrayRef mPluginList;
	LoadedPlugin *mLoadedPluginChain;
//	CFStringRef mCurrentPluginName;
//	CFMutableArrayRef mCurrentItemList;
//	CFIndex			mCurrentMenuItemIndex;
	CFDictionaryRef mChosenItemInfo;//retained and owned

//	int			mCurrentContextType;
	AEDesc		mAETextContext;
	AEDescList	mAEFileContext;
	AEDescList	mAEFolderContext;
	CFStringRef mContextText;
	CFStringRef mContextFilePath;
	CFStringRef mContextFolderPath;
	int			mActiveHotKeyDialog;
}

- (IBAction)cmMenuItemSelected:(id)sender;
- (IBAction)showHotKeyDialogForContextualMenu:(id)sender;

- (void)editItem:(CFIndex)itemIndex;

- (IBAction)chooseFile:(id)sender;
- (IBAction)chooseFolder:(id)sender;
- (IBAction)setContextInfo:(id)sender;
- (IBAction)closeHotKeyDialog: (id)sender;

- (void)findAndAssignShortcut;

- (BOOL)showFileChoiceDialog;
- (BOOL)showFolderChoiceDialog;

- (void)readPreferences:(id)sender;
- (void)savePreferences:(id)sender;

- (void)contextChanged:(int)contextID;
- (void)menuNeedsUpdate:(NSMenu *)menu;

- (void)buildMenu:(NSMenu *)inMenu forPlugin:(CFURLRef)inPluginURLRef withContext:(AEDesc *)contextDesc;
- (OSStatus)buildMenuLevel:(NSMenu *)inMenu forPlugin:(CFURLRef)inPluginURLRef
							//itemList:(CFMutableArrayRef)ioList
							submenuPath:(CFURLRef)inSubmenuPath forAElist:(AEDescList*)inMenuItemsList
							usingTextContext: (Boolean)inPrefersText;

- (BOOL)getFSRefFromPath:(NSString *)inPath toRef: (FSRef *)ioRef;
- (OSErr)createAliasDesc:(const FSRef *)inFSRef toAlias:(AEDesc *)outAliasAEDesc;
- (void)showHotKeyDialogForMenuItem;
- (CFMutableArrayRef)getShortcutList;
- (void)changeMenuItemHotKey:(CFStringRef)newKeyChar keyCode:(CFIndex)newKeyCode modifiers:(CFIndex)newModifiers reset:(BOOL)doReset;
- (void)changeContextualMenuHotKey:(CFStringRef)newKeyChar keyCode:(CFIndex)newKeyCode modifiers:(CFIndex)newModifiers reset:(BOOL)doReset;

+ (unsigned int) getModifiersFromCarbonModifiers:(CFIndex)inCarbonModifiers;
+ (NSString *)getLongHotKeyString:(NSString *)inKeyChar withModifiers:(unsigned int)inModifiers;
+ (NSString *)getShortHotKeyString:(NSString*)inKeyChar withModifiers:(unsigned int)inModifiers;

@end
