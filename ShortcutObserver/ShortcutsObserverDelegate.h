//
//  ShortcutsObserverDelegate.h
//  ShortcutObserver
//
//  Created by Tomasz Kukielka on 3/15/09.
//  Copyright 2009-2010 Abracode Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "RegisteredShortcuts.h"
#include "PluginLoading.h"
#include "ShortcutList.h"
#include "ContextProviders.h"

@interface ShortcutsObserverDelegate : NSObject <NSMenuDelegate>
{
	CFArrayRef mShortcutList;
	CFArrayRef mPluginList;
	LoadedPlugin *mLoadedPluginChain;
	EventHotKeyRef mContexMenuShortcutRef;
	RegisteredShortcut *mRegisteredShortcutChain;
	ComponentInstance mOSAComponent;
	CFBundleRef mMainBundle;
	ContextScriptInfo *mTextContexProviders; 
	ContextScriptInfo *mAliasContexProviders; 

	AEDesc mContextDesc;
	NSMenu *mCMItemsMenu;
	NSTimer *mPostMenuCleanupTimer;
}

- (void)registerContextMenuShortcut;
- (void)registerAllShortcuts;
- (void)reloadShortcuts;
- (void)handleShortcutEvent:(UInt32)shortcutID;
- (OSStatus)createContext:(AEDesc *)outDesc forFrontApp:(NSString *)frontAppName frontAppPSN:(ProcessSerialNumber *)psnPtr prefersText:(Boolean)prefersTextContext;
- (OSAID)loadAppleScript:(const FSRef *)inFileRef;
- (void)executeAppleScript:(OSAID)inScriptID resultDesc:(AEDesc *)outDesc getTextResult:(Boolean)getTextResult;
- (void)executeCMPlugin:(CFURLRef)inPluginURLRef submenuPath:(CFURLRef)inSubmenuPath itemName:(CFStringRef)inItemName prefersText:(Boolean)prefersTextContext;
- (void)showContextualMenu:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
- (void)populateContextualMenu:(NSMenu *)menu forContext:(AEDesc *)contextDesc;
- (void)buildMenu:(NSMenu *)inMenu forPlugin:(CFURLRef)inPluginURLRef withContext:(AEDesc *)contextDesc;
- (OSStatus)buildMenuLevel:(NSMenu *)inMenu forPlugin:(CFURLRef)inPluginURLRef
							submenuPath:(CFURLRef)inSubmenuPath forAElist:(AEDescList*)inMenuItemsList
							usingTextContext: (Boolean)inPrefersText;

- (void)cmMenuItemSelected:(id)sender;
//- (void)menuDidEndTrackingNotification:(NSNotification *)inNotification;
//- (void)menuWillSendActionNotification:(NSNotification *)inNotification;
- (void)postMenuCleanup;
- (void)createAEListForFiles:(NSArray *)inFileNames;
- (BOOL)getFSRefFromPath:(NSString *)inPath toRef: (FSRef *)ioRef;
- (OSErr)createAliasDesc:(const FSRef *)inFSRef toAlias:(AEDesc *)outAliasAEDesc;

@end
