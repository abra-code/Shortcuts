#import "ShortcutsController.h"
#include "BuildCMPluginList.h"
#include "ExtractCMItemData.h"
#include "ShortcutList.h"
#include "AEDescText.h"

CFIndex kShortcutsVersion = 2;

const AEDesc kEmptyAEDesc =  {typeNull, NULL};
CFStringRef kShortcutsIdentifier = CFSTR("com.abracode.Shortcuts");
CFStringRef kShortcutObserverPortName = CFSTR("T9NM2ZLDTY.AbracodeShortcutObserverPort");

extern const UniChar kCmdGlyph;
extern const UniChar kOptionGlyph;
extern const UniChar kControlGlyph;
extern const UniChar kShiftGlyph;

enum
{
	kMessagePrefsChanged = 1
};

static inline NSUInteger CarbonToCocoaMenuModifiers(UInt32 inCarbonModifiers)
{
	NSUInteger modifiers = 0;

    if((inCarbonModifiers & kMenuShiftModifier) != 0)
		modifiers |= NSShiftKeyMask;	

    if((inCarbonModifiers & kMenuOptionModifier) != 0)
		modifiers |= NSAlternateKeyMask;

    if((inCarbonModifiers & kMenuControlModifier) != 0)
		modifiers |= NSControlKeyMask;

	return modifiers;
}


@implementation ShortcutsController

- (id)init
{
    if (![super init])
        return nil;
	
	mShortcutList = NULL;
	mPluginList = NULL;
	mLoadedPluginChain = NULL;
	mChosenItemInfo = NULL;
	mAETextContext = kEmptyAEDesc;
	mAEFileContext = kEmptyAEDesc;
	mAEFolderContext = kEmptyAEDesc;

	mTextItemsMenu = NULL;
	mFileItemsMenu = NULL;
	mFolderItemsMenu = NULL;
	mActiveHotKeyDialog = kHotKeyDialog_None;

	return self;
}

- (void)dealloc
{
    if(mShortcutList != NULL)
		CFRelease(mShortcutList);
	
    if(mPluginList != NULL)
		CFRelease(mPluginList);

	ReleaseLoadedPluginChain(mLoadedPluginChain);
	
//	if(mCurrentPluginName != NULL)
//		CFRelease(mCurrentPluginName);

	if(mChosenItemInfo != NULL)
		CFRelease(mChosenItemInfo);

	if((mAETextContext.descriptorType != typeNull) && (mAETextContext.dataHandle != NULL))
		AEDisposeDesc(&mAETextContext);
	mAETextContext = kEmptyAEDesc;

	if((mAEFileContext.descriptorType != typeNull) && (mAEFileContext.dataHandle != NULL))
		AEDisposeDesc(&mAEFileContext);
	mAEFileContext = kEmptyAEDesc;

	if((mAEFolderContext.descriptorType != typeNull) && (mAEFolderContext.dataHandle != NULL))
		AEDisposeDesc(&mAEFolderContext);
	mAEFolderContext = kEmptyAEDesc;
}


- (void)awakeFromNib
{
    [self readPreferences:NULL];
	mPluginList = BuildCMPluginList();

	mTextItemsMenu = [mTextItemsPopup menu];
	[mTextItemsMenu setDelegate:self];
	[mTextItemsMenu setAutoenablesItems:YES];

	mFileItemsMenu = [mFileItemsPopup menu];
	[mFileItemsMenu setDelegate:self];
	[mFileItemsMenu setAutoenablesItems:YES];

	mFolderItemsMenu = [mFolderItemsPopup menu];
	[mFolderItemsMenu setDelegate:self];
	[mFolderItemsMenu setAutoenablesItems:YES];
	
	[mTextContextField setStringValue: NSLocalizedString(@"Example_Text",@"") ];
	[self contextChanged:1];

	NSBundle *myBundle = [NSBundle mainBundle];
	if(myBundle != NULL)
	{
//		NSString *resourcePath = [myBundle resourcePath];

		NSString *exampleFilePath = [myBundle pathForResource:@"Example file" ofType:@"png" inDirectory:NULL];
		if(exampleFilePath != NULL)
		{
			[mFileContextField setStringValue: exampleFilePath];
			[self contextChanged:2];
		}

		NSString *exampleFolderPath = [myBundle pathForResource:@"Example folder" ofType:NULL inDirectory:NULL];
		if(exampleFolderPath != NULL)
		{
			[mFolderContextField setStringValue: exampleFolderPath];
			[self contextChanged:3];
		}
	}

	CFPropertyListRef resultRef = CFPreferencesCopyAppValue( CFSTR("VERSION"), kShortcutsIdentifier );
	if(resultRef == NULL)
	{//no prefs yet, this is probably the first launch so update the services list to include ShortcutObserver
		NSUpdateDynamicServices();//Apple docs say it does not work for running apps - so Finder would not get a refresh?
	}

	NSString *longString = @"<none>";
	NSString *shortString = @"";

	resultRef = CFPreferencesCopyAppValue( CFSTR("SHOW_MENU_SHORTCUT"), kShortcutsIdentifier );
	if( (resultRef != NULL) && (CFGetTypeID(resultRef) == CFDictionaryGetTypeID()) )
	{
		CFStringRef keyChar = NULL;
		CFIndex hotKeyCode = 0;
		CFIndex hotKeyModifiers = 0;
		CopyShortcutKeyAndModifiers( (CFDictionaryRef)resultRef, &keyChar, &hotKeyModifiers, &hotKeyCode);
		CFRelease(resultRef);
		
		if(keyChar != NULL)
		{
			unsigned int cocoaModifiers = [ShortcutsController getModifiersFromCarbonModifiers:hotKeyModifiers];
			longString = [ShortcutsController getLongHotKeyString:(__bridge NSString *)keyChar withModifiers:cocoaModifiers];
			shortString = [ShortcutsController getShortHotKeyString:(__bridge NSString *)keyChar withModifiers:cocoaModifiers];
			CFRelease(keyChar);
		}
	}

	[mContextMenuLongHotKey setStringValue: longString];
	[mContextMenuShortHotKey setStringValue: shortString];

	mActiveHotKeyDialog = kHotKeyDialog_None;
}

/*
- (IBAction)contextChange:(id)sender
{
	int senderTag = [sender tag];
	//if(mContextPopup != NULL)
	{
		//int index = [mContextPopup indexOfSelectedItem];
		//if(index >= 0)
		{
			switch(senderTag)
			{
				case 0:
				{//none
					//[mChooseFileButt setEnabled: FALSE];
					if(sender != self)
					{
						[mContextField setStringValue:@""];
					}
				//	mCurrentContextType = 0;
				}
				break;
				
				case 1:
				{//text
					[mContextField setEnabled: TRUE];
					//[mChooseFileButt setEnabled: FALSE];
					
					OSStatus err = CreateUniTextDescFromCFString(mContextText, &mTextContext);
					if(sender != self)
						[mContextField setStringValue: (NSString*)mContextText];
					
					//mCurrentContextType = 1;
					[self menuNeedsUpdate:mTextItemsMenu];
				}
				break;
				
				case 2:
				{//file list
					BOOL isOK = TRUE;
					if(mContextFilePath == NULL)
						isOK = [self showFileChoiceDialog];
					else
						[mContextField setStringValue: (NSString*)mContextFilePath];
					
					if(isOK)
					{
						[mContextField setEnabled: TRUE];
						//[mChooseFileButt setEnabled: TRUE];
						//OSErr err = AEDuplicateDesc(&mFileContext, &mContextDesc);
						//mCurrentContextType = 2;
						[self menuNeedsUpdate:mFileItemsMenu];
					}
					
					//else
					//{//the dialog may be cancelled and we need to know
					//	//use old context type to revert to previous choice
					//	[mContextPopup selectItemAtIndex:mCurrentContextType];
					//}
				}
				break;

				case 3:
				{//folder list
					BOOL isOK = TRUE;
					if(mContextFolderPath == NULL)
						isOK = [self showFolderChoiceDialog];
					else
						[mContextField setStringValue: (NSString*)mContextFolderPath];
					
					if(isOK)
					{
						[mContextField setEnabled: TRUE];
						//[mChooseFileButt setEnabled: TRUE];
						//OSErr err = AEDuplicateDesc(&mFolderContext, &mContextDesc);
						//mCurrentContextType = 3;
						[self menuNeedsUpdate:mFolderItemsMenu];
					}
					//else
					//{//the dialog may be cancelled and we need to know
					//	//use old context type to revert to previous choice
					//	[mContextPopup selectItemAtIndex:mCurrentContextType];
					//}
				
				}
				break;
			}
			
			
		}
	}
}
*/

- (IBAction)cmMenuItemSelected:(id)sender
{
	NSMenuItem *menuItem = (NSMenuItem *)sender;

	if(mChosenItemInfo != NULL)
		CFRelease(mChosenItemInfo);
	mChosenItemInfo = NULL;
	
    NSDictionary *menuItemInfo = menuItem.representedObject;
    mChosenItemInfo = (CFDictionaryRef)CFBridgingRetain(menuItemInfo);
	if(mChosenItemInfo != NULL)
	{
		CFRetain(mChosenItemInfo);
		[self showHotKeyDialogForMenuItem];
	}
}

-(void)editItem:(CFIndex)itemIndex
{
	if(mChosenItemInfo != NULL)
		CFRelease(mChosenItemInfo);
	mChosenItemInfo = NULL;

	if( mShortcutList == NULL )
		return;

	CFIndex	theCount = CFArrayGetCount(mShortcutList);
	if( (itemIndex >= 0) && (itemIndex < theCount) )
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(mShortcutList, itemIndex);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == CFDictionaryGetTypeID()) )
		{
			mChosenItemInfo = (CFDictionaryRef)theItem;
			CFRetain(mChosenItemInfo);
			[self showHotKeyDialogForMenuItem];
		}
	}
}


- (void)readPreferences:(id)sender
{
	CFPreferencesAppSynchronize(kShortcutsIdentifier);
	if(mShortcutList != NULL)
		CFRelease(mShortcutList);
	mShortcutList = LoadMutableShortcutListFromPrefs(kShortcutsIdentifier, CFSTR("CM_SHORTCUTS"));
}

- (void)savePreferences:(id)sender
{
	CFMessagePortRef observerPort = NULL;
	SaveShortcutsToPrefs(kShortcutsIdentifier, CFSTR("CM_SHORTCUTS"), mShortcutList);

	CFNumberRef versionNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType , &kShortcutsVersion);
	CFPreferencesSetAppValue( CFSTR("VERSION"), (CFPropertyListRef)versionNum, kShortcutsIdentifier );
	CFRelease(versionNum);

	CFPreferencesAppSynchronize(kShortcutsIdentifier);

	if( mShortcutTableView != NULL)
		[mShortcutTableView reloadData];

	observerPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kShortcutObserverPortName);
	if(observerPort != NULL)
	{
		SInt32 result = CFMessagePortSendRequest(
						observerPort,
						kMessagePrefsChanged, //msgid
						NULL, //data
						0,//send timeout
						0,//rcv timout
						NULL, //kCFRunLoopDefaultMode
						NULL//replyData
						);		
		if(result != 0)
			fprintf(stderr, "An error ocurred when sending request to ShortcutObserver port: %d\n", (int)result);
		CFRelease(observerPort);
	}
	//else: Observer not running
}

- (CFMutableArrayRef)getShortcutList
{
	if(mShortcutList == NULL)
		[self readPreferences:self];
	return mShortcutList;
}

#pragma mark -
#pragma mark NSMenu Delegate

- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{
	return TRUE;
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	if(mActiveHotKeyDialog != kHotKeyDialog_None)
		return;

	int itemCount = [menu numberOfItems];
	int i;
	for(i = (itemCount-1); i >= 0; i--)
	{
		[menu removeItemAtIndex:i];
	}

	if(mChosenItemInfo != NULL)
		CFRelease(mChosenItemInfo);
	mChosenItemInfo = NULL;

	if(mPluginList == NULL)
		return;

	AEDesc *contextDesc = NULL;
	if(menu == mTextItemsMenu)
		contextDesc = &mAETextContext;
	else if(menu == mFileItemsMenu)
		contextDesc = &mAEFileContext;
	else if(menu == mFolderItemsMenu)
		contextDesc = &mAEFolderContext;

	if(contextDesc == NULL)
		return;

	CFIndex	theCount = CFArrayGetCount(mPluginList);
	
	//change: build menu for all plugins as it would be normally done by cm manager
	for(i = 0; i < theCount; i++)
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(mPluginList, i/*selectedPluginIndex*/);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == CFURLGetTypeID()) )
		{
			CFURLRef onePluginURL = (CFURLRef)theItem;
			[self buildMenu:menu forPlugin:onePluginURL withContext: contextDesc];
		}
	}
}

#pragma mark -

- (void)buildMenu:(NSMenu *)inMenu forPlugin:(CFURLRef)inPluginURLRef withContext:(AEDesc *)contextDesc
{
	OSStatus err = noErr;
	
	ContextualMenuInterfaceStruct **interface = NULL;
	
	if(inPluginURLRef == NULL)
		return;

	if(mLoadedPluginChain != NULL)
		interface = FindLoadedPlugin(mLoadedPluginChain, inPluginURLRef);
	
	if(interface == NULL)
	{
		interface = LoadPlugin(inPluginURLRef);
		if(interface != NULL)
			mLoadedPluginChain = AddLoadedPluginToChain(mLoadedPluginChain, inPluginURLRef, interface);
	}
	
	if(interface == NULL)
	{
		printf("ShortcutController->buildMenu:forPlugin:withContext. Could not load the plugin\n");
		return;
	}
	
	AEDescList menuItemsList = {typeNull, NULL};
	err = AECreateList(NULL, 0, false, &menuItemsList);
	if(err == noErr)
	{
		err = (*interface)->ExamineContext(interface, contextDesc, &menuItemsList );
		if(err == noErr)
		{
			//recursive menu builder
			CFURLRef rootLevel = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("/"), kCFURLPOSIXPathStyle, true);
			//mCurrentItemList = CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );
			err = [self buildMenuLevel:inMenu
						forPlugin:(CFURLRef)inPluginURLRef
						//itemList:mCurrentItemList
						submenuPath:rootLevel
						forAElist: &menuItemsList
						usingTextContext: (contextDesc->descriptorType == typeUnicodeText) ? true : false];
			CFRelease(rootLevel);

			(*interface)->PostMenuCleanup(interface);
		}
		
		err = AEDisposeDesc(&menuItemsList);
	}

}

- (OSStatus)buildMenuLevel:(NSMenu *)inMenu forPlugin:(CFURLRef)inPluginURLRef
							//itemList:(CFMutableArrayRef)ioList
							submenuPath:(CFURLRef)inSubmenuPath forAElist:(AEDescList*)inMenuItemsList
							usingTextContext: (Boolean)inPrefersText
{
	long itemCount = 0;
	CFStringRef oneMenuName = NULL;
	SInt32 oneCommandID = 0;
	UInt32 oneMenuAttribs = 0;
	UInt32 oneMenuModifiers = kMenuNoModifiers;
	Boolean isSubmenu = false;
	AEDescList submenuList = {typeNull, NULL};
	Boolean previousItemWasDynamic = false;

	OSStatus err = AECountItems(inMenuItemsList, &itemCount);
	if(err != noErr)
		return err;

	NSString *keyArray[2];
	id valueArray[2];
	NSColor *redColor = [NSColor redColor];
	keyArray[0] = NSForegroundColorAttributeName;
	valueArray[0] = redColor;

	NSFont *sysFont = [NSFont menuFontOfSize:14.0];//systemFontOfSize
	keyArray[1] = NSFontAttributeName;
	valueArray[1] = sysFont;
	
	NSDictionary *redMenuTextAttr = [NSDictionary dictionaryWithObjects:valueArray forKeys:keyArray count:2];
	
//	NSDictionary *redColorAttribs = [NSDictionary dictionaryWithObject:redColor forKey:NSForegroundColorAttributeName];

	
	SInt32 i;
	for(i = 1; i <= itemCount; i++)
	{
		// Get nth item in the list
		AEDesc oneItem;
		AEKeyword theKeyword;
		err = AEGetNthDesc(inMenuItemsList, i, typeWildCard, &theKeyword, &oneItem);
		if((err == noErr) && AECheckIsRecord (&oneItem))
		{
			oneMenuName = NULL;
			oneCommandID = 0;
			oneMenuAttribs = 0;
			oneMenuModifiers = kMenuNoModifiers;
			isSubmenu = false;
			submenuList.descriptorType = typeNull;
			submenuList.dataHandle = NULL;

			err = ExtractCMItemData(&oneItem,
							&oneMenuName, &oneCommandID, &oneMenuAttribs, &oneMenuModifiers,
							&isSubmenu, &submenuList );
			
			if( err == noErr )
			{
				NSMenuItem *menuItem = NULL;
				BOOL isSeparator = NO;
				if((oneMenuAttribs & kMenuItemAttrSeparator) != 0)
				{//explicit separator
					isSeparator = YES;
				}
				else if( ((oneMenuAttribs & kMenuItemAttrIgnoreMeta) == 0) && (oneMenuName != NULL) )
				{//if metas are not ignored, check for dash as first char in name
					CFIndex theLen = CFStringGetLength(oneMenuName);
					if(theLen > 0)
					{
						UniChar theFirst = CFStringGetCharacterAtIndex(oneMenuName, 0);
						if(theFirst == (UniChar)'-')
							isSeparator = YES;
					}
				}
				
				if(isSeparator)
				{
					menuItem = (NSMenuItem*)[NSMenuItem separatorItem];
					[inMenu addItem:menuItem];
				}
				else if(oneMenuName != NULL)
				{
					menuItem = (NSMenuItem*)[inMenu addItemWithTitle:(__bridge NSString *)oneMenuName action:@selector(cmMenuItemSelected:) keyEquivalent:@""];
				}
				
				if( (menuItem != NULL) && (oneMenuName != NULL) )
				{
					[menuItem setTarget:self];
					[menuItem setState:NSOffState];
					[menuItem setEnabled:YES];
					
					//check for dynamic menu items with modifier keys
					if( ((oneMenuAttribs & kMenuItemAttrDynamic) != 0) &&
						((oneMenuAttribs & kMenuItemAttrNotPreviousAlternate) == 0) &&
						previousItemWasDynamic )
					{
						[menuItem setAlternate:YES];
						NSUInteger cocoaModifiers = CarbonToCocoaMenuModifiers(oneMenuModifiers);
						[menuItem setKeyEquivalentModifierMask:cocoaModifiers];
					}

					if( isSubmenu )
					{
						NSMenu *subMenu = [[NSMenu alloc] initWithTitle:(__bridge NSString *)oneMenuName];
						[inMenu setSubmenu:(NSMenu *)subMenu forItem:menuItem];
						CFURLRef newPath = CFURLCreateCopyAppendingPathComponent(
											kCFAllocatorDefault,
											inSubmenuPath,
											oneMenuName,
											true);
						err = [self buildMenuLevel:subMenu forPlugin:inPluginURLRef
													//itemList:ioList
													submenuPath:newPath
													forAElist: &submenuList
													usingTextContext: inPrefersText];//recursive digger
						CFRelease(newPath);
					}
					else
					{//good, add this item to our array
						CFStringRef submenuPathStr = CFURLCopyFileSystemPath(inSubmenuPath, kCFURLPOSIXPathStyle);//needs to be released
						CFStringRef currentPluginName = CFURLCopyLastPathComponent(inPluginURLRef);//needs to be released

#if 1
						//find if it has hotkey assigned
						CFIndex keyModifiers = 0;
						CFIndex keyCode = 0;
						CFStringRef keyChar = NULL;
						CFIndex	foundIndex = FindShortcut(
												mShortcutList,
												currentPluginName,
												submenuPathStr,
												oneMenuName,
												&keyChar,
												&keyModifiers,
												&keyCode);
						if(foundIndex >= 0)
						{//hotkey assigned - make the menu red
							/*
							NSAttributedString *oldAttrString = [menuItem attributedTitle];
							NSMutableAttributedString *mutableAttrStr = [[NSAttributedString alloc] initWithAttributedString:oldAttrString ];
							[mutableAttrStr autorelease];
							NSRange wholeRange = NSMakeRange(0, [mutableAttrStr length]);
							[mutableAttrStr addAttribute:NSForegroundColorAttributeName value:redColor range:wholeRange];
							*/
							//[oldAttrString attribute:(NSString *)attributeName atIndex:0 effectiveRange:NULL];
							NSAttributedString *redStr = [[NSAttributedString alloc] initWithString:(__bridge NSString*)oneMenuName attributes:redMenuTextAttr];
							[menuItem setAttributedTitle:redStr];
							if(keyChar != NULL)
								CFRelease(keyChar);
						}
#endif
						
						CFMutableDictionaryRef theDict = CFDictionaryCreateMutable(
											kCFAllocatorDefault,
											0,
											&kCFTypeDictionaryKeyCallBacks,
											&kCFTypeDictionaryValueCallBacks);
						if(theDict!= NULL)
						{
							CFDictionarySetValue(theDict, CFSTR("PLUGIN_URL"), inPluginURLRef);
							CFDictionarySetValue(theDict, CFSTR("NAME"), oneMenuName);
							if(submenuPathStr != NULL)
								CFDictionarySetValue(theDict, CFSTR("SUBMENU"), submenuPathStr);//retained

							CFNumberRef commandID = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &oneCommandID);
							CFDictionarySetValue(theDict, CFSTR("ID"), commandID);//retained
							CFRelease(commandID);
							CFDictionarySetValue(theDict, CFSTR("PREFERS_TEXT_CONTEXT"), inPrefersText ? kCFBooleanTrue : kCFBooleanFalse );
                            menuItem.representedObject = CFBridgingRelease(theDict);
						}
						CFRelease(submenuPathStr);
						CFRelease(currentPluginName);
					}
				}
				if(oneMenuName != NULL)
					CFRelease(oneMenuName);

				previousItemWasDynamic = ((oneMenuAttribs & kMenuItemAttrDynamic) != 0);
			}

			if(submenuList.dataHandle != NULL)
				AEDisposeDesc(&submenuList);
			
			AEDisposeDesc(&oneItem);
		}
	}
	return err;
}

- (IBAction)chooseFile:(id)sender
{
	OSStatus err;
	BOOL isOK = [self showFileChoiceDialog];

	if(isOK && (sender != self))
	{
	/*
		if((mContextDesc.descriptorType != typeNull) && (mContextDesc.dataHandle != NULL))
			AEDisposeDesc(&mContextDesc);
		mContextDesc = kEmptyAEDesc;
		err = AEDuplicateDesc(&mFileContext, &mContextDesc);
	*/
		[self menuNeedsUpdate:mFileItemsMenu];
	}
}

- (IBAction)chooseFolder:(id)sender
{
	OSStatus err;
	BOOL isOK = [self showFolderChoiceDialog];

	if(isOK && (sender != self))
	{
	/*
		if((mContextDesc.descriptorType != typeNull) && (mContextDesc.dataHandle != NULL))
			AEDisposeDesc(&mContextDesc);
		mContextDesc = kEmptyAEDesc;
		err = AEDuplicateDesc(&mFolderContext, &mContextDesc);
	*/
		[self menuNeedsUpdate:mFolderItemsMenu];
	}
}

- (BOOL)showFileChoiceDialog
{
	OSStatus err;
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    if(oPanel == NULL)
        return FALSE;

	[oPanel setTitle:NSLocalizedString(@"Choose file for context simulation",@"")];
    [oPanel setPrompt:NSLocalizedString(@"Select",@"")];
	[oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel setAllowsMultipleSelection:NO];
    
    if ([oPanel runModalForTypes:nil] == NSOKButton)
    {
		NSArray *files = [oPanel filenames];
		int count = [files count];
		int i;
		for (i = 0; i < count; i++)
		{
			NSString *aFile = [files objectAtIndex:i];
			FSRef oneRef;
			memset(&oneRef, 0, sizeof(oneRef));
			BOOL isOK = [self getFSRefFromPath:aFile toRef: &oneRef];
			if(isOK)
			{
				AEDesc aliasDesc = kEmptyAEDesc;
				err = [self createAliasDesc: &oneRef toAlias: &aliasDesc];
				if(err == noErr)
				{
					if((mAEFileContext.descriptorType != typeNull) && (mAEFileContext.dataHandle != NULL))
						AEDisposeDesc(&mAEFileContext);
					mAEFileContext = kEmptyAEDesc;

					err = AECreateList( NULL, 0, false, &mAEFileContext );
					if(err == noErr)
						err = AEPutDesc( &mAEFileContext, 0, &aliasDesc );
				
					AEDisposeDesc(&aliasDesc);
					
					if(err == noErr)
					{
						self.contextFilePath = aFile;
						[mFileContextField setStringValue:self.contextFilePath];
						return TRUE;
					}
				}
			}
		}
    }

	return FALSE;
}

- (BOOL)showFolderChoiceDialog
{
	OSStatus err;
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    if(oPanel == NULL)
        return FALSE;

	[oPanel setTitle:NSLocalizedString(@"Choose folder for context simulation",@"")];
    [oPanel setPrompt:NSLocalizedString(@"Select",@"")];
    [oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];
    [oPanel setAllowsMultipleSelection:NO];
    
    if ([oPanel runModalForTypes:nil] == NSOKButton)
    {
		NSArray *files = [oPanel filenames];
		int count = [files count];
		int i;
		for (i = 0; i < count; i++)
		{
			NSString *aFile = [files objectAtIndex:i];
			FSRef oneRef;
			memset(&oneRef, 0, sizeof(oneRef));
			BOOL isOK = [self getFSRefFromPath:aFile toRef: &oneRef];
			if(isOK)
			{
				AEDesc aliasDesc = kEmptyAEDesc;
				err = [self createAliasDesc: &oneRef toAlias: &aliasDesc];
				if(err == noErr)
				{
					if((mAEFolderContext.descriptorType != typeNull) && (mAEFolderContext.dataHandle != NULL))
						AEDisposeDesc(&mAEFolderContext);
					mAEFolderContext = kEmptyAEDesc;

					err = AECreateList( NULL, 0, false, &mAEFolderContext );
					if(err == noErr)
						err = AEPutDesc( &mAEFolderContext, 0, &aliasDesc );
				
					AEDisposeDesc(&aliasDesc);
					
					if(err == noErr)
					{
						self.contextFolderPath = aFile;
						[mFolderContextField setStringValue:self.contextFolderPath];
						return TRUE;
					}
				}
			}
		}
    }

	return FALSE;
}


- (BOOL)getFSRefFromPath:(NSString *)inPath toRef: (FSRef *)ioRef
{
    if((inPath == NULL) || (ioRef == NULL))
        return FALSE;

    CFURLRef urlRef = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)inPath, kCFURLPOSIXPathStyle, false);
    if(urlRef != NULL)
    {
        Boolean isOK = CFURLGetFSRef(urlRef, ioRef);
		CFRelease(urlRef);
		return isOK;
    }
    return FALSE;
}


- (OSErr)createAliasDesc:(const FSRef *)inFSRef toAlias:(AEDesc *)outAliasAEDesc
{
	OSErr			err = noErr;
	AliasHandle		aliasHandle = NULL;

	err = FSNewAlias( NULL, inFSRef, &aliasHandle );

	if(err != noErr)
		return err;

	if(aliasHandle == NULL)
		return paramErr;

	HLock((Handle)aliasHandle);	
	err = AECreateDesc( typeAlias, *aliasHandle, GetHandleSize((Handle)aliasHandle), outAliasAEDesc );
	HUnlock((Handle)aliasHandle);
	DisposeHandle((Handle)aliasHandle);

	return err;
}

- (void)textDidChange:(NSNotification *)aNotification
{
	//printf("\ntextDidChange called\n");
}

- (IBAction)setContextInfo:(id)sender
{
	int senderTag = [sender tag];
	[self contextChanged:senderTag];
}

- (void)contextChanged:(int)contextID
{
	if(contextID == 1)//text
	{
		self.contextText = [mTextContextField stringValue];
		if((mAETextContext.descriptorType != typeNull) && (mAETextContext.dataHandle != NULL))
			AEDisposeDesc(&mAETextContext);
		mAETextContext = kEmptyAEDesc;
		OSStatus err = CreateUniTextDescFromCFString((__bridge CFStringRef)self.contextText, &mAETextContext);
		[self menuNeedsUpdate:mTextItemsMenu];
	}
	else if(contextID == 2)//file path
	{
		self.contextFilePath = [mFileContextField stringValue];
		
		FSRef oneRef;
		memset(&oneRef, 0, sizeof(oneRef));
		BOOL isOK = [self getFSRefFromPath:self.contextFilePath toRef: &oneRef];
		if(isOK)
		{
			int multiSelState = [mFileMultipleSelection state];
			AEDesc aliasDesc = kEmptyAEDesc;
			OSStatus err = [self createAliasDesc: &oneRef toAlias: &aliasDesc];
			if(err == noErr)
			{
				if((mAEFileContext.descriptorType != typeNull) && (mAEFileContext.dataHandle != NULL))
					AEDisposeDesc(&mAEFileContext);
				mAEFileContext = kEmptyAEDesc;

				err = AECreateList( NULL, 0, false, &mAEFileContext );
				if(err == noErr)
				{
					err = AEPutDesc( &mAEFileContext, 0, &aliasDesc );

					if(multiSelState == NSOnState) //put the same thingy twice so there will be mutliple files
						err = AEPutDesc( &mAEFileContext, 0, &aliasDesc );
				}

				AEDisposeDesc(&aliasDesc);
			}
		}
		[self menuNeedsUpdate:mFileItemsMenu];
	}
	else if(contextID == 3)//folder path
	{
		self.contextFolderPath = [mFolderContextField stringValue];
		
		FSRef oneRef;
		memset(&oneRef, 0, sizeof(oneRef));
		BOOL isOK = [self getFSRefFromPath:self.contextFolderPath toRef: &oneRef];
		if(isOK)
		{
			int multiSelState = [mFolderMultipleSelection state];

			AEDesc aliasDesc = kEmptyAEDesc;
			OSStatus err = [self createAliasDesc: &oneRef toAlias: &aliasDesc];
			if(err == noErr)
			{
				if((mAEFolderContext.descriptorType != typeNull) && (mAEFolderContext.dataHandle != NULL))
					AEDisposeDesc(&mAEFolderContext);
				mAEFolderContext = kEmptyAEDesc;

				err = AECreateList( NULL, 0, false, &mAEFolderContext );
				if(err == noErr)
				{
					err = AEPutDesc( &mAEFolderContext, 0, &aliasDesc );
					
					if(multiSelState == NSOnState) //put the same thingy twice so there will be mutliple files
						err = AEPutDesc( &mAEFolderContext, 0, &aliasDesc );
				}

				AEDisposeDesc(&aliasDesc);
			}
		}
		[self menuNeedsUpdate:mFolderItemsMenu];
	}
}

- (void)showHotKeyDialogForMenuItem
{
	[self findAndAssignShortcut];

	mActiveHotKeyDialog = kHotKeyDialog_ForMenuItem;
    [NSApp beginSheet: mHotKeyDialog
            modalForWindow: mMainShortcutWindow
            modalDelegate: NULL //self
            didEndSelector: NULL //@selector(shortcutSheetDidEnd:returnCode:contextInfo:)
            contextInfo: NULL];
}

-(IBAction)showHotKeyDialogForContextualMenu:(id)sender
{
	CFPropertyListRef resultRef = CFPreferencesCopyAppValue( CFSTR("SHOW_MENU_SHORTCUT"), kShortcutsIdentifier );
	if(resultRef == NULL)
	{
		[mHotKeyDialog resetHotKey];
	}
	else if( CFGetTypeID(resultRef) == CFDictionaryGetTypeID() )
	{
		CFStringRef keyChar = NULL;
		CFIndex hotKeyCode = 0;
		CFIndex hotKeyModifiers = 0;
		CopyShortcutKeyAndModifiers( (CFDictionaryRef)resultRef, &keyChar, &hotKeyModifiers, &hotKeyCode);
		CFRelease(resultRef);
		if(keyChar != NULL)
		{
			[mHotKeyDialog setHotKey:hotKeyCode withModifiers:hotKeyModifiers withKeyChar:keyChar];
			CFRelease(keyChar);
		}
		else
			[mHotKeyDialog resetHotKey];
	}

	mActiveHotKeyDialog = kHotKeyDialog_ForContextMenu;
    [NSApp beginSheet: mHotKeyDialog
            modalForWindow: mMainShortcutWindow
            modalDelegate: NULL //self
            didEndSelector: NULL //@selector(shortcutSheetDidEnd:returnCode:contextInfo:)
            contextInfo: NULL];
}

- (void)findAndAssignShortcut
{
	if( mChosenItemInfo == NULL )
		return;

	CFStringRef itemName = NULL;
	CFStringRef submenuPath = NULL;//own
	CFStringRef currentPluginName = NULL;//own

	CFTypeRef theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("NAME") );
	if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
	{
		itemName = (CFStringRef)theResult;
	}
	
	theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("SUBMENU") );
	if( (theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
	{
		submenuPath = (CFStringRef)CFRetain(theResult);
	}
	/*
	if( (theResult != NULL) && (CFURLGetTypeID() == CFGetTypeID(theResult)) )
	{
		submenuPath = CFURLCopyFileSystemPath((CFURLRef)theResult, kCFURLPOSIXPathStyle);//needs to be released
	}
	*/
	
	theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("PLUGIN_URL") );
	if( (theResult != NULL) && (CFURLGetTypeID() == CFGetTypeID(theResult)) )
	{
		CFURLRef pluginURL = (CFURLRef)theResult;
		if(pluginURL != NULL)
			currentPluginName = CFURLCopyLastPathComponent(pluginURL);//needs to be released
	}

	if(currentPluginName == NULL)
	{
		theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("PLUGIN") );
		if( (theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
		{
			currentPluginName = (CFStringRef)theResult;
			CFRetain(currentPluginName);//needs to be released
		}
	}

	if(submenuPath == NULL)
	{
		if(currentPluginName != NULL)
			CFRelease(currentPluginName);
		[mHotKeyDialog resetHotKey];
		return;
	}

	if(currentPluginName == NULL)
	{
		CFRelease(submenuPath);
		[mHotKeyDialog resetHotKey];
		return;
	}

	if(itemName == NULL)
	{
		CFRelease(submenuPath);
		CFRelease(currentPluginName);
		[mHotKeyDialog resetHotKey];
		return;
	}

	[mHotKeyDialog setShortcutList:mShortcutList pluginName:currentPluginName submenuPath:submenuPath menuName:itemName];

	CFIndex oldModifiers = 0;
	CFIndex oldKeyCode = 0;
	CFStringRef keyChar = NULL;
	CFIndex	foundIndex = FindShortcut(
							mShortcutList,
							currentPluginName,
							submenuPath,
							itemName,
							&keyChar,
							&oldModifiers,
							&oldKeyCode);

	if(foundIndex >= 0)
	{//existing item found
		if(keyChar == NULL)
		{
			keyChar = CFSTR("");
			CFRetain(keyChar);
		}
		[mHotKeyDialog setHotKey:oldKeyCode withModifiers:oldModifiers withKeyChar:keyChar];
		CFRelease(keyChar);
	}
	else
	{//not found - reset
		[mHotKeyDialog resetHotKey];
	}
	
	CFRelease(submenuPath);
	CFRelease(currentPluginName);
}

- (IBAction)closeHotKeyDialog: (id)sender
{
	[NSApp endSheet: mHotKeyDialog];
	[mHotKeyDialog orderOut: self];

	int senderTag = [sender tag];
	if(senderTag == 3)//cancel
		return;


	CFIndex newModifiers = (CFIndex)[mHotKeyDialog getCarbonModifiers];
	CFIndex newKeyCode = (CFIndex)[mHotKeyDialog getKeyCode];
	CFStringRef newKeyChar = [mHotKeyDialog getKeyChar];
	if(newKeyChar != NULL)
	{
		CFRetain(newKeyChar);
	}
	else
	{
		newKeyChar = CFSTR("");
		CFRetain(newKeyChar);
	}

	if(mActiveHotKeyDialog == kHotKeyDialog_ForContextMenu)
	{
		[self changeContextualMenuHotKey:newKeyChar keyCode:newKeyCode modifiers:newModifiers reset:(senderTag == 2)];
	}
	else if(mActiveHotKeyDialog == kHotKeyDialog_ForMenuItem)
	{
		[self changeMenuItemHotKey:newKeyChar keyCode:newKeyCode modifiers:newModifiers reset:(senderTag == 2)];
	}
	
	mActiveHotKeyDialog = kHotKeyDialog_None;
	CFRelease(newKeyChar);
}

-(void)changeMenuItemHotKey:(CFStringRef)newKeyChar keyCode:(CFIndex)newKeyCode modifiers:(CFIndex)newModifiers reset:(BOOL)doReset
{
	CFStringRef itemName = NULL;
	CFStringRef submenuPath = NULL;//own
	CFStringRef currentPluginName = NULL;//own

	CFTypeRef theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("NAME") );
	if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
	{
		itemName = (CFStringRef)theResult;
	}
	
	theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("SUBMENU") );
	
	if( (theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
	{
		submenuPath = (CFStringRef)CFRetain(theResult);
	}
	
	/*
	if( (theResult != NULL) && (CFURLGetTypeID() == CFGetTypeID(theResult)) )
	{
	
		submenuPath = CFURLCopyFileSystemPath((CFURLRef)theResult, kCFURLPOSIXPathStyle);//needs to be released
	}
	*/

	theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("PLUGIN_URL") );
	if( (theResult != NULL) && (CFURLGetTypeID() == CFGetTypeID(theResult)) )
	{
		CFURLRef pluginURL = (CFURLRef)theResult;
		if(pluginURL != NULL)
			currentPluginName = CFURLCopyLastPathComponent(pluginURL);//needs to be released
	}
		
	if(currentPluginName == NULL)
	{
		theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("PLUGIN") );
		if( (theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
		{
			currentPluginName = (CFStringRef)theResult;
			CFRetain(currentPluginName);//needs to be released
		}
	}

	Boolean pefersTextContext = false;
	theResult = CFDictionaryGetValue( mChosenItemInfo, CFSTR("PREFERS_TEXT_CONTEXT") );
	if((theResult != NULL) && (CFBooleanGetTypeID() == CFGetTypeID(theResult)) )
		pefersTextContext = CFBooleanGetValue(theResult);

	if(submenuPath == NULL)
	{
		CFRelease(newKeyChar);
		if(currentPluginName != NULL)
			CFRelease(currentPluginName);
		return;
	}

	if(currentPluginName == NULL)
	{
		CFRelease(newKeyChar);
		CFRelease(submenuPath);
		return;
	}

	if(itemName == NULL)
	{
		CFRelease(newKeyChar);
		CFRelease(submenuPath);
		CFRelease(currentPluginName);
		return;
	}


	CFIndex oldModifiers = 0;
	CFIndex oldKeyCode = 0;
	CFIndex	foundIndex = FindShortcut(
							mShortcutList,
							currentPluginName,
							submenuPath,
							itemName,
							NULL,
							&oldModifiers,
							&oldKeyCode);
	
	if(foundIndex >= 0)
	{//existing item found
		//when assigning different item or removing we need to delete old one
		if( doReset || ((oldModifiers != newModifiers) || (oldKeyCode != newKeyCode))  )
		{
			CFArrayRemoveValueAtIndex(mShortcutList, foundIndex);
		}
	}
	
	if( !doReset && ((oldModifiers != newModifiers) || (oldKeyCode != newKeyCode)) )
	{//add new shortcut		
		AddShortcut(
				mShortcutList,
				currentPluginName,
				submenuPath,
				itemName,
				newKeyChar,
				newModifiers,
				newKeyCode,
				pefersTextContext);
	}

	//save prefs after each change
	[self savePreferences:NULL];

	CFRelease(submenuPath);
	CFRelease(currentPluginName);
}


-(void)changeContextualMenuHotKey:(CFStringRef)newKeyChar keyCode:(CFIndex)newKeyCode modifiers:(CFIndex)newModifiers reset:(BOOL)doReset
{
	CFDictionaryRef menuShortcutDict = NULL;
	if(!doReset)
		menuShortcutDict = CreateShortcutKeyAndModifiersDictionary(newKeyChar, newModifiers, newKeyCode);
	CFPreferencesSetAppValue( CFSTR("SHOW_MENU_SHORTCUT"), (CFPropertyListRef)menuShortcutDict, kShortcutsIdentifier );

	//remmeber to save version in prefs
	CFNumberRef versionNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType , &kShortcutsVersion);
	CFPreferencesSetAppValue( CFSTR("VERSION"), (CFPropertyListRef)versionNum, kShortcutsIdentifier );
	CFRelease(versionNum);

	CFPreferencesAppSynchronize(kShortcutsIdentifier);
	if(menuShortcutDict != NULL)
		CFRelease(menuShortcutDict);
	
	CFMessagePortRef observerPort = CFMessagePortCreateRemote(kCFAllocatorDefault, kShortcutObserverPortName);
	if(observerPort != NULL)
	{
		SInt32 result = CFMessagePortSendRequest(
						observerPort,
						kMessagePrefsChanged, //msgid
						NULL, //data
						0,//send timeout
						0,//rcv timout
						NULL, //kCFRunLoopDefaultMode
						NULL//replyData
						);		
		if(result != 0)
			fprintf(stderr, "An error ocurred when sending request to ShortcutObserver port: %d\n", (int)result);
		CFRelease(observerPort);
	}

	NSString *longString = @"<none>";
	NSString *shortString = @"";
	if(!doReset)
	{
		unsigned int cocoaModifiers = [ShortcutsController getModifiersFromCarbonModifiers:newModifiers];
		longString = [ShortcutsController getLongHotKeyString:(__bridge NSString *)newKeyChar withModifiers:cocoaModifiers];
		shortString = [ShortcutsController getShortHotKeyString:(__bridge NSString *)newKeyChar withModifiers:cocoaModifiers];
	}
	[mContextMenuLongHotKey setStringValue: longString];	
	[mContextMenuShortHotKey setStringValue: shortString];	
}

+ (unsigned int) getModifiersFromCarbonModifiers:(CFIndex)inCarbonModifiers
{
	unsigned int modifiers = 0;

    if((inCarbonModifiers & cmdKey) != 0)
		modifiers |= NSCommandKeyMask;

    if((inCarbonModifiers & shiftKey) != 0)
		modifiers |= NSShiftKeyMask;	

    if((inCarbonModifiers & alphaLock) != 0)
		modifiers |= NSAlphaShiftKeyMask;

    if((inCarbonModifiers & optionKey) != 0)
		modifiers |= NSAlternateKeyMask;

    if((inCarbonModifiers & controlKey) != 0)
		modifiers |= NSControlKeyMask;

	return modifiers;
}


+ (NSString *)getShortHotKeyString:(NSString*)theKey withModifiers:(unsigned int)modifiers
{
	NSMutableString *shortString = [NSMutableString string];
	
    if((modifiers & NSControlKeyMask) != 0)
	{
		[shortString appendString: [NSString stringWithCharacters: &kControlGlyph length:1]];
	}

    if((modifiers & NSAlternateKeyMask) != 0)
	{
		[shortString appendString: [NSString stringWithCharacters: &kOptionGlyph length:1]];
	}

    if((modifiers & NSShiftKeyMask) != 0)
	{
		[shortString appendString: [NSString stringWithCharacters: &kShiftGlyph length:1]];
	}
	
    if((modifiers & NSCommandKeyMask) != 0)
	{
		[shortString appendString: [NSString stringWithCharacters: &kCmdGlyph length:1]];
	}

	NSString *upperKey = NULL;
	if([theKey length] == 1)
		upperKey = [theKey uppercaseString];
	else
		upperKey = theKey;

	[shortString appendString:upperKey];
	
	return shortString;
}

+(NSString *)getLongHotKeyString:(NSString *)inKeyChar withModifiers:(unsigned int)inModifiers
{
	NSMutableString *displayString = [NSMutableString string];
    if((inModifiers & NSControlKeyMask) != 0)
		[displayString appendString:@"Control+"];

    if((inModifiers & NSAlternateKeyMask) != 0)
		[displayString appendString:@"Option+"];

    if((inModifiers & NSShiftKeyMask) != 0)
		[displayString appendString:@"Shift+"];
	
    if((inModifiers & NSCommandKeyMask) != 0)
		[displayString appendString:@"Command+"];
	
	NSString *upperKey = NULL;
	if([inKeyChar length] == 1)
		upperKey = [inKeyChar uppercaseString];
	else
		upperKey = inKeyChar;

	[displayString appendString: upperKey];

	return displayString;	
}

//the return code here is not what we want
/*
- (void)shortcutSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
}
*/

@end

