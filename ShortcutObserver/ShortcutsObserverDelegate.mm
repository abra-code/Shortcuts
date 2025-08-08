//
//  ShortcutsObserverDelegate.m
//  ShortcutObserver
//
//  Created by Tomasz Kukielka on 3/15/09.
//  Copyright 2009-2010 Abracode Inc. All rights reserved.
//

#import "ShortcutsObserverDelegate.h"
#include "BuildCMPluginList.h"
#include "CocoaBezelWindow.h"
#include "AEDescText.h"
#include "FinderContext.h"
#include "ExtractCMItemData.h"
#include "CFObj.h"

CFStringRef kShortcutsIdentifier = CFSTR("com.abracode.Shortcuts");

enum
{
	kMessagePrefsChanged = 1
};

static ShortcutsObserverDelegate *sShortcutsObserverDelegate = NULL;
static SInt32 sSysVersion = 10*10000 + 4*100 + 0;

enum
{
	kMacOSVersion10_4_0 =  10*10000 + 4*100 + 0,
	kMacOSVersion10_5_0 =  10*10000 + 5*100 + 0,
	kMacOSVersion10_6_0 =  10*10000 + 6*100 + 0
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


ContextScriptInfo *
FindContextProviders(CFBundleRef inBundleRef, CFStringRef inSubfolder)
{
	ContextScriptInfo *outProviderChain = NULL;
	CFObj<CFArrayRef> contextScripts = CFBundleCopyResourceURLsOfType( inBundleRef, NULL/*CFSTR("scpt")*/, inSubfolder );
	if(contextScripts != NULL)
	{
		CFStringRef oneName = NULL;
		CFIndex	theCount = CFArrayGetCount(contextScripts);
		CFIndex i;
		for(i = 0; i < theCount; i++)
		{
			CFTypeRef theItem = CFArrayGetValueAtIndex(contextScripts, i);
			if( (theItem != NULL) && (CFGetTypeID(theItem) == CFURLGetTypeID()) )
			{
				CFURLRef oneURL = (CFURLRef)theItem;
				FSRef fileRef;
				memset(&fileRef, 0, sizeof(fileRef));
				Boolean isFileRefValid = CFURLGetFSRef(oneURL, &fileRef);

				CFObj<CFURLRef> newURL = CFURLCreateCopyDeletingPathExtension( kCFAllocatorDefault, oneURL );
				oneName = CFURLCopyLastPathComponent(newURL);
				if(isFileRefValid)
					outProviderChain = AddScriptToChain( outProviderChain, oneName, &fileRef );
			}
		}
	}
	return outProviderChain;
}

//retain result pluginURLRef if you plan to keep it
CFURLRef
FindPlugin(CFArrayRef pluginList, CFStringRef inPluginName)
{
	if( (pluginList == NULL) || (inPluginName == NULL) )
		return NULL;

	CFURLRef foundPlugin = NULL;
	CFIndex	theCount = CFArrayGetCount(pluginList);
	CFIndex i;
	for(i = 0; i < theCount; i++)
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(pluginList, i);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == CFURLGetTypeID()) )
		{
			CFURLRef onePluginURL = (CFURLRef)theItem;
			CFObj<CFStringRef> oneName = CFURLCopyLastPathComponent(onePluginURL);
			if(oneName != nullptr)
			{
				if( kCFCompareEqualTo == CFStringCompare(inPluginName, oneName, 0) )
				{
					foundPlugin = onePluginURL;
				}
			}
		}
		if(foundPlugin != NULL)
			break;
	}
	return foundPlugin;
}



CFDataRef ShortcutObserverListenerProc(CFMessagePortRef local, SInt32 msgid, CFDataRef inData, void *info);

void
InstallMessageListenerPort()
{
	CFMessagePortRef    localPort = NULL;
    CFRunLoopSourceRef  runLoopSource = NULL;
    CFRunLoopRef        runLoopRef = NULL;
    CFMessagePortContext messagePortContext = { 0, NULL, NULL, NULL, NULL };
	CFStringRef			portName = CFSTR("T9NM2ZLDTY.AbracodeShortcutObserverPort");

   localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, portName, ShortcutObserverListenerProc, &messagePortContext, NULL);
	//no need to release the localPort, it will be present always
	if(localPort == NULL)
		return;

    runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
	if(runLoopSource == NULL)
		return;

    runLoopRef = CFRunLoopGetCurrent();
    
    CFRunLoopAddSource(runLoopRef, runLoopSource, kCFRunLoopDefaultMode);
}

CFDataRef
ShortcutObserverListenerProc(CFMessagePortRef local, SInt32 msgid, CFDataRef inData, void *info)
{
	if( (msgid == kMessagePrefsChanged) && (sShortcutsObserverDelegate != NULL) )
		[sShortcutsObserverDelegate reloadShortcuts];

	return NULL;
}


pascal OSStatus ShortcutEventHandler( EventHandlerCallRef inCallRef, EventRef inEvent, void* inUserData );

void
SetupShortcutEventHandler()
{
	EventTypeSpec eventSpecList[1];
	eventSpecList[0].eventClass = kEventClassKeyboard;
	eventSpecList[0].eventKind = kEventHotKeyPressed;
	
	/*OSStatus err =*/ InstallEventHandler (
						GetApplicationEventTarget(),
						NewEventHandlerUPP(ShortcutEventHandler),
						sizeof(eventSpecList)/sizeof(EventTypeSpec),
						eventSpecList,
						NULL,//void * inUserData,
						NULL);//EventHandlerRef * outRef
}

pascal OSStatus
ShortcutEventHandler( EventHandlerCallRef inCallRef,
						EventRef inEvent,
						void* inUserData )
{
	OSStatus err = eventNotHandledErr;
	EventHotKeyID myShortcutID = { 0, 0 };

#if _DEBUG_
	printf("Some event received by ShortcutEventHandler. Checking...\n");
#endif

	if( (GetEventClass(inEvent) != kEventClassKeyboard) || (GetEventKind(inEvent) != kEventHotKeyPressed) )
	{
#if _DEBUG_
		printf("The event received is not kEventClassKeyboard/kEventHotKeyPressed. Exiting...\n");
#endif
		return eventNotHandledErr;
	}

	err = GetEventParameter( inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(EventHotKeyID), NULL, &myShortcutID );
	if(err != noErr)
	{
#if _DEBUG_
		printf("Error obtaining typeEventHotKeyID. Exiting...\n");
#endif
		return err;
	}
	
	@try
	{
		@autoreleasepool
		{
			if(myShortcutID.signature == 'AbSc')
			{
		#if _DEBUG_
				printf("Shortcut hotkey combination pressed, shortcut id is: %d\n", (int)myShortcutID.id);
		#endif
				if(sShortcutsObserverDelegate != NULL)
					[sShortcutsObserverDelegate handleShortcutEvent:myShortcutID.id];
				
			}
			else if( (myShortcutID.signature == 'AbCx') && (myShortcutID.id == 13) )
			{
		#if _DEBUG_
				printf("Shortcut hotkey for menu pressed, shortcut id is: %d\n", (int)myShortcutID.id);
		#endif
				if(sShortcutsObserverDelegate != NULL)
				{
					NSString *errString = NULL;
					[sShortcutsObserverDelegate showContextualMenu:NULL userData:NULL error:&errString];
				}
				else
				{
		#if _DEBUG_
					printf("Error: sShortcutsObserverDelegate is NULL!\n");
		#endif
				}
			}
			else
			{
		#if _DEBUG_
				printf("Unknown hotkey pressed, signature=0x%x, id=%d\n", (int)myShortcutID.signature, (int)myShortcutID.id);
		#endif		
			}
		}
	}
	@catch (NSException *localException)
	{
		NSLog(@"ShortcutEventHandler received exception: %@", localException);
	}

	return eventNotHandledErr;
}


void
ShowErrorWindow(CFStringRef messageText, CFStringRef errorBezelName)
{
	if(errorBezelName == nullptr)
		return;

	CFPreferencesAppSynchronize( kShortcutsIdentifier );
	CFObj<CFStringRef> bezelImageName = (CFStringRef)CFPreferencesCopyAppValue( CFSTR("BEZEL_IMAGE"), kShortcutsIdentifier );
	if( (bezelImageName != nullptr) && (CFGetTypeID(bezelImageName) != CFStringGetTypeID()) )
	{// not a string
		return;//not using window notification
	}

	if(bezelImageName == nullptr)
		return;//not using window notification

	//using window notification
	ShowBezelWindow((__bridge NSString *)messageText, nil, (__bridge NSString *)errorBezelName, @"Error Bezels" );
}


//ioList must be preallocated before calling this function
//inSubmenuPath must list sumbenus up to the level where we are
OSStatus
BuildContextualMenuItemsList(const AEDescList *inMenuItemsList, CFMutableArrayRef ioList, CFURLRef inSubmenuPath)
{
	long itemCount = 0;
	SInt32 oneCommandID = 0;
	UInt32 oneMenuAttribs = 0;
	UInt32 oneMenuModifiers = kMenuNoModifiers;
	Boolean isSubmenu = false;
	SInt32 i;
	AEDescList submenuList;
	AEInitializeDescInline(&submenuList);

	OSStatus err = AECountItems(inMenuItemsList, &itemCount);
	if(err != noErr)
		return err;

	for(i = 1; i <= itemCount; i++)
	{
		// Get nth item in the list
		AEDesc oneItem;
		AEInitializeDescInline(&oneItem);
		AEKeyword theKeyword;
		err = AEGetNthDesc(inMenuItemsList, i, typeWildCard, &theKeyword, &oneItem);
		if(err != noErr)
			continue;
		
		if(AECheckIsRecord (&oneItem))
		{
			oneCommandID = 0;
			isSubmenu = false;
			AEInitializeDescInline(&submenuList);
			oneMenuAttribs = 0;
			oneMenuModifiers = kMenuNoModifiers;
			
			CFObj<CFStringRef> oneMenuName;
			err = ExtractCMItemData(&oneItem,
							&oneMenuName, &oneCommandID, &oneMenuAttribs, &oneMenuModifiers,
							&isSubmenu, &submenuList );
			
			if((err == noErr) && (oneMenuName != nullptr))
			{
				if(isSubmenu)
				{
					CFObj<CFURLRef> newPath = CFURLCreateCopyAppendingPathComponent(
										kCFAllocatorDefault,
										inSubmenuPath,
										oneMenuName,
										true);
					
					err = BuildContextualMenuItemsList(&submenuList, ioList, newPath);//recursive submenu digger
				}
				else
				{//good, add this item to our array
				
#if 0 //_DEBUG_
					CFShow(oneMenuName);
#endif

					CFObj<CFMutableDictionaryRef> theDict = CFDictionaryCreateMutable(
										kCFAllocatorDefault,
										0,
										&kCFTypeDictionaryKeyCallBacks,
										&kCFTypeDictionaryValueCallBacks);
					if(theDict!= NULL)
					{
						CFDictionarySetValue(theDict, CFSTR("NAME"), oneMenuName);
						CFDictionarySetValue(theDict, CFSTR("SUBMENU"), inSubmenuPath);//retained
						CFObj<CFNumberRef> commandID = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &oneCommandID);
						CFDictionarySetValue(theDict, CFSTR("ID"), commandID);//retained
						CFArrayAppendValue( ioList, (const void *)theDict );//retained
					}
				}
			}
			
			if(submenuList.dataHandle != NULL)
				AEDisposeDesc(&submenuList);
		}
		AEDisposeDesc(&oneItem);
	}
	return err;
}


Boolean
FindMenuItem(CFArrayRef menuItemsArray, CFURLRef inSubmenuPath, CFStringRef inItemName, SInt32 *outCommandID)
{
	Boolean isFound = false;
	CFIndex	theCount = CFArrayGetCount(menuItemsArray);
	CFIndex i;

#if _DEBUG_
	static char debugBuff[1024];

	debugBuff[0] = 0;
	CFStringGetCString(inItemName, debugBuff, sizeof(debugBuff), kCFStringEncodingUTF8);
	printf("ShortcutObserver. FindMenuItem. Looking for menu: %s\n", debugBuff);

	CFObj<CFStringRef> myPath = CFURLCopyFileSystemPath(inSubmenuPath, kCFURLPOSIXPathStyle);
	debugBuff[0] = 0;
	CFStringGetCString(myPath, debugBuff, sizeof(debugBuff), kCFStringEncodingUTF8);
	printf("ShortcutObserver. FindMenuItem. Submenu path: %s\n", debugBuff);

	printf("ShortcutObserver. FindMenuItem. number of items in array = %d\n", (int)theCount);
	
#endif

	for(i = 0; i < theCount; i++)
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(menuItemsArray, i);
#if _DEBUG_
		if(theItem != NULL)
			CFShow(theItem);
		else
			printf("ShortcutObserver. FindMenuItem. CFArrayGetValueAtIndex returned NULL for item=%d\n", (int)i);
#endif

		if( (theItem != NULL) && (CFGetTypeID(theItem) == CFDictionaryGetTypeID()) )
		{
			CFDictionaryRef theDict = (CFDictionaryRef)theItem;
			CFTypeRef theResult = CFDictionaryGetValue( theDict, CFSTR("NAME") );
			if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
			{
#if _DEBUG_
				debugBuff[0] = 0;
				CFStringGetCString((CFStringRef)theResult, debugBuff, sizeof(debugBuff), kCFStringEncodingUTF8);
				printf("\tCurrent menu name at index=%d: %s\n", (int)i, debugBuff);
#endif
				if( kCFCompareEqualTo == CFStringCompare(inItemName, (CFStringRef)theResult, 0) )
				{//name equal, now check submenu path
#if _DEBUG_
					printf("!!!name equal, check for submenu path\n");
#endif
					theResult = CFDictionaryGetValue( theDict, CFSTR("SUBMENU") );
					if((theResult != NULL) && (CFURLGetTypeID() == CFGetTypeID(theResult)) )
					{
#if _DEBUG_
						myPath.Adopt(CFURLCopyFileSystemPath((CFURLRef)theResult, kCFURLPOSIXPathStyle));
						debugBuff[0] = 0;
						CFStringGetCString(myPath, debugBuff, sizeof(debugBuff), kCFStringEncodingUTF8);
						printf("!!!item submenu path: %s\n", debugBuff);
#endif
						if(CFEqual(inSubmenuPath, theResult))
						{
#if _DEBUG_
							printf("!!!submenu paths equal\n");
#endif
							theResult = CFDictionaryGetValue( theDict, CFSTR("ID") );
							if((theResult != NULL) && (CFNumberGetTypeID() == CFGetTypeID(theResult)) )
							{
#if _DEBUG_
								printf("!!!found item ID is of CFNumber type. good\n");
#endif
								if( CFNumberGetValue((CFNumberRef)theResult, kCFNumberSInt32Type, outCommandID) )
								{
#if _DEBUG_
									printf("!!found item ID=%d \n", (int)*outCommandID);
#endif
									isFound = true;
									break;
								}
							}
						}
					}
				}
			}
		}
	}
	return isFound;
}

static inline
CFStringRef CopyCurrentTextSelectionWithAccessibility()
{
	CFObj<AXUIElementRef> systemWideElement = AXUIElementCreateSystemWide();
	CFObj<AXUIElementRef> focusedElement;
	AXError error = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
	if(error != kAXErrorSuccess)
		return nil;

	AXValueRef selectedTextValue = nullptr;
	error = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute, (CFTypeRef *)&selectedTextValue);
	if (error == kAXErrorSuccess)
	{
		return (CFStringRef)selectedTextValue;
	}
	return nil;
}


@implementation ShortcutsObserverDelegate

- (id)init
{
    if (![super init])
        return nil;
	
	mShortcutList = NULL;
	mPluginList = NULL;
	mLoadedPluginChain = NULL;
	mContexMenuShortcutRef = NULL;
	mRegisteredShortcutChain = NULL;
	mOSAComponent = NULL;
	mMainBundle = NULL;
	mTextContexProviders = NULL;
	mAliasContexProviders = NULL;
	AEInitializeDescInline(&mContextDesc);
	mCMItemsMenu = NULL;

	mMainBundle = CFBundleGetMainBundle();
	if(mMainBundle != NULL)
		CFRetain(mMainBundle);

	SInt32 sysVerMajor = 10;
	SInt32 sysVerMinor = 4;
	SInt32 sysVerBugFix = 0;
	Gestalt(gestaltSystemVersionMajor, &sysVerMajor);
	Gestalt(gestaltSystemVersionMinor, &sysVerMinor);
	Gestalt(gestaltSystemVersionBugFix, &sysVerBugFix);

	sSysVersion = 10000 * sysVerMajor + 100 * sysVerMinor + sysVerBugFix;
	
	sShortcutsObserverDelegate = self;
	return self;
}

//we dealloc this controller only when we quit
- (void)dealloc
{
	sShortcutsObserverDelegate = NULL;

//	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
//	[notificationCenter removeObserver:self];

	if(mPostMenuCleanupTimer != NULL)
	{
		[mPostMenuCleanupTimer invalidate];
		mPostMenuCleanupTimer = NULL;
	}

	mCMItemsMenu = NULL;
	
	if(mContextDesc.dataHandle != NULL)
		AEDisposeDesc(&mContextDesc);

    if(mPluginList != NULL)
		CFRelease(mPluginList);
	mPluginList = NULL;

	ReleaseLoadedPluginChain(mLoadedPluginChain);

	if(mOSAComponent != NULL)
		CloseComponent(mOSAComponent);
	mOSAComponent = NULL;

	if(mMainBundle != NULL)
		CFRelease(mMainBundle);
	mMainBundle = NULL;
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	CFPreferencesAppSynchronize(kShortcutsIdentifier);
	mShortcutList = LoadShortcutsFromPrefs(kShortcutsIdentifier, CFSTR("CM_SHORTCUTS"));
	mPluginList = BuildCMPluginList();

	SetupShortcutEventHandler();
	[self registerAllShortcuts];

	mOSAComponent = OpenDefaultComponent( kOSAComponentType, kOSAGenericScriptingComponentSubtype );
	mTextContexProviders = FindContextProviders( mMainBundle, CFSTR("Text Context Providers") );
	mAliasContexProviders = FindContextProviders( mMainBundle, CFSTR("Alias Context Providers") );
	
	NSApplication *observerApp = [NSApplication sharedApplication];
	[observerApp unhideWithoutActivation];
	[observerApp setServicesProvider:self];

// install listener - needed for prefs refresh when main "Shortcuts" app modified the prefs
	InstallMessageListenerPort();

// just prime the pump on start - call Accessibility API to get the user
// to accept the system dialog and go to preferences to allow Shortcuts Observer

	NSString *selectedText = nullptr;
	CFObj<AXUIElementRef> systemWideElement = AXUIElementCreateSystemWide();
	CFObj<AXUIElementRef> focusedElement;
/*	AXError error =*/ AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
/*
	if(error == kAXErrorSuccess)
	{
		AXValueRef selectedTextValue = nullptr;
		error = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute, (CFTypeRef *)&selectedTextValue);
		if (error == kAXErrorSuccess)
			selectedText = (NSString *)(selectedTextValue);
	}
*/

//test - show the context menu on startup
#if 0
	NSString *errorString = NULL;
	[self showContextualMenu:NULL userData:NULL error:&errorString];
#endif
}

- (void)registerContextMenuShortcut
{
	EventHotKeyID myShortcutID;
	myShortcutID.signature = 'AbCx';
	myShortcutID.id = 13;
	CFIndex hotKeyCode;
	CFIndex hotKeyModifiers;
	OSStatus err;
	EventTargetRef appTarget = GetApplicationEventTarget();
	
	if(mContexMenuShortcutRef != NULL)
	{
		UnregisterEventHotKey(mContexMenuShortcutRef);
		mContexMenuShortcutRef = NULL;
	}

	CFObj<CFPropertyListRef> resultRef = CFPreferencesCopyAppValue( CFSTR("SHOW_MENU_SHORTCUT"), kShortcutsIdentifier );
	if(resultRef == nullptr)
		return;

	if( CFGetTypeID(resultRef) == CFDictionaryGetTypeID() )
	{
		CopyShortcutKeyAndModifiers( (CFDictionaryRef)(CFPropertyListRef)resultRef, NULL, &hotKeyModifiers, &hotKeyCode);
		
		if(hotKeyCode != 0)
		{
			err = RegisterEventHotKey(
						(UInt32)hotKeyCode,
						(UInt32)hotKeyModifiers,
						myShortcutID,
						appTarget,
						0, //OptionBits inOptions, Currently unused. Pass 0 or face the consequences.
						&mContexMenuShortcutRef);
		}
	}
}


- (void)registerAllShortcuts
{
	EventHotKeyRef shortcutRef = NULL;
	EventHotKeyID myShortcutID;
	myShortcutID.signature = 'AbSc';
	myShortcutID.id = -1;
	CFIndex hotKeyCode;
	CFIndex hotKeyModifiers;
	OSStatus err;

#if _DEBUG_
	printf("Shortcut Observer->RegisterAllShortcuts\n");
#endif

	[self registerContextMenuShortcut];

	if(mRegisteredShortcutChain != NULL)
	{
		ReleaseRegisteredShortcutChain(mRegisteredShortcutChain);
		mRegisteredShortcutChain = NULL;
	}

	if(mShortcutList == NULL)
		return;

	EventTargetRef appTarget = GetApplicationEventTarget();

	UInt32 theCount = (UInt32)CFArrayGetCount(mShortcutList);
	for(UInt32 i = 0; i < theCount; i++)
	{
		FetchShortcutKeyAndModifiers(mShortcutList, i, NULL, &hotKeyModifiers, &hotKeyCode);
		if(hotKeyCode != 0)
		{
			shortcutRef = NULL;
			myShortcutID.id = i;
			err = RegisterEventHotKey(
						(UInt32)hotKeyCode,
						(UInt32)hotKeyModifiers,
						myShortcutID,
						appTarget,
						0, //OptionBits inOptions, Currently unused. Pass 0 or face the consequences.
						&shortcutRef);
			if( (err == noErr) && (shortcutRef != NULL) )
				mRegisteredShortcutChain = AddRegisteredShortcutToChain(mRegisteredShortcutChain, shortcutRef);
		}
	}
}

- (void)reloadShortcuts
{
	CFPreferencesAppSynchronize(kShortcutsIdentifier);
	if(mShortcutList != NULL)
		CFRelease(mShortcutList);
	mShortcutList = LoadShortcutsFromPrefs(kShortcutsIdentifier, CFSTR("CM_SHORTCUTS"));
	[self registerAllShortcuts];
}


- (void)handleShortcutEvent:(UInt32)shortcutID
{
	if(mShortcutList == NULL)
		return;

	CFIndex	theCount = CFArrayGetCount(mShortcutList);
	if( shortcutID < theCount )
	{
		CFStringRef pluginName = NULL;
		CFStringRef submenuPath = NULL;
		CFStringRef menuItemName = NULL;
		Boolean prefersTextContext = false;

		FetchShortcutMenuItemData(
				mShortcutList,
				shortcutID,
				&pluginName,
				&submenuPath,
				&menuItemName,
				&prefersTextContext);
		
		CFURLRef pluginURLRef = FindPlugin(mPluginList, pluginName);
		
		if( (pluginURLRef != NULL) && (submenuPath != NULL) && (menuItemName != NULL) )
		{
			CFObj<CFURLRef> subPathURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, submenuPath, kCFURLPOSIXPathStyle, true);
			if(subPathURL != NULL)
			{
				[self executeCMPlugin:pluginURLRef submenuPath:subPathURL itemName:menuItemName prefersText:prefersTextContext];
			}
			else
			{
	#if _DEBUG_
				printf("Shortcut Observer -> cannot finde plugin bundle\n");
	#endif					
				ShowErrorWindow(menuItemName, CFSTR("CannotFind"));
			}
		}
		else
		{
	#if _DEBUG_
			printf("Shortcut Observer -> plugin not found\n");
	#endif
			ShowErrorWindow(menuItemName, CFSTR("CannotFind"));
		}
	}
	else
	{
	#if _DEBUG_
		printf("Shortcut Observer -> logic error. item index out of bounds\n");
	#endif
	}
}


//this is the best attempt to obtain context information from remote app
//- (OSStatus)createFrontAppContext:(AEDesc *)outDesc prefersText:(Boolean)prefersTextContext
- (OSStatus)createContext:(AEDesc *)outDesc forFrontApp:(NSString *)processName frontAppPSN:(ProcessSerialNumber *)psnPtr prefersText:(Boolean)prefersTextContext
{
#if _DEBUG_
		printf("Shortcut Observer. Entering CreateFrontAppContext with prefersTextContext = %s\n", prefersTextContext ? "true" : "false");
#endif

	if((outDesc == nullptr) || (processName == nil))
		return paramErr;

	AEInitializeDescInline(outDesc);

	if((prefersTextContext == false) && [processName isEqualToString:@"Finder"])
	{
#if _DEBUG_
		printf("Shortcut Observer->CreateFrontAppContext. Front process is Finder\n");
#endif
		CreateFinderContext(psnPtr, outDesc);
	}
	else
	{
		ContextScriptInfo* currScript = FindScriptByName(prefersTextContext? mTextContexProviders : mAliasContexProviders, (__bridge CFStringRef)processName);
		if(currScript != NULL)
		{
#if _DEBUG_
			printf("Shortcut Observer->CreateFrontAppContext. FindScriptByName found script for our front app\n");
#endif
			if(currScript->scriptRef == kOSANullScript)
				currScript->scriptRef = [self loadAppleScript: &(currScript->fileRef)];
			[self executeAppleScript:currScript->scriptRef resultDesc:outDesc getTextResult:prefersTextContext];
		}
		else
		{
			CFObj<CFStringRef> currSelectionText = CopyCurrentTextSelectionWithAccessibility();
			if(currSelectionText != nullptr)
				CreateUniTextDescFromCFString(currSelectionText, outDesc);
		}
	}

	return noErr;
}


- (OSAID)loadAppleScript:(const FSRef *)inFileRef
{
	OSAID resultScript = kOSANullScript;
	if(mOSAComponent == NULL)
		mOSAComponent = OpenDefaultComponent( kOSAComponentType, kOSAGenericScriptingComponentSubtype );

	OSAError err = OSALoadFile( mOSAComponent, inFileRef, NULL, kOSAModeNull, //kOSAModePreventGetSource
								&resultScript );
	if(err != noErr)
	{
		printf("Shortcut Observer->LoadAppleScript. OSALoadFile returned error: %d\n", (int)err);
	}
	return resultScript;
}

- (void)executeAppleScript:(OSAID)inScriptID resultDesc:(AEDesc *)outDesc getTextResult:(Boolean)getTextResult
{
	OSAID resultID = kOSANullScript;
	OSAError err = OSAExecute( mOSAComponent, inScriptID, kOSANullScript,
								kOSAModeCanInteract, &resultID );
	if(err == noErr)
	{
		if(getTextResult)
			err = OSADisplay(mOSAComponent, resultID, typeUnicodeText, kOSAModeDisplayForHumans, outDesc);
		else
		{
			AEDesc aliasOrList;
			AEInitializeDescInline(&aliasOrList);
			err = OSACoerceToDesc(mOSAComponent, resultID, typeWildCard, kOSAModeNull, &aliasOrList);
			if(aliasOrList.descriptorType != typeAEList)
			{//always make a list if single element returned
				err = AECreateList(NULL, 0, false, outDesc);
				if(err == noErr)
				{
					AEPutDesc(outDesc, 0, &aliasOrList);
					AEDisposeDesc(&aliasOrList);
				}
			}
			else
			{
				*outDesc = aliasOrList;
			}
		}
		
		OSADispose( mOSAComponent, resultID);
		if(err != noErr)
		{
			printf("Shortcut Observer->LoadAppleScript. OSADisplay returned error: %d\n", (int)err);
		}
	}
	else
	{
		printf("Shortcut Observer->ExecuteAppleScript. OSAExecute returned error: %d\n", (int)err);
		if(err == errOSAScriptError)
		{
			AEDesc errDesc;
			AEInitializeDescInline(&errDesc);
			err = OSAScriptError(mOSAComponent,
						kOSAErrorMessage,
						typeUTF8Text,
						&errDesc);
			if(err == noErr)
			{
#if _DEBUG_
				CFObj<CFStringRef> descStr = CreateCFStringFromAEDesc(&errDesc);
				if(descStr != NULL)
				{
					CFShow(descStr);
				}
#endif
				AEDisposeDesc(&errDesc);
			}
		}
	}
}


//load CM plugins
/*‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî*/
/*  Contextual Menu Plugin Interface                                                    */
/*                                                                                      */
/*  For Mac OS X 10.1, we support a new type of Contextual Menu Plugin: the CFPlugIn    */
/*  based plugin.  Each plugin must be in a CFPlugIn in the Contextual Menu Items       */
/*  folder in one of these paths:                                                       */
/*      /System/Library/Contextual Menu Items/                                          */
/*      /Library/Contextual Menu Items/                                                 */
/*      ~/Library/Contextual Menu Items/                                                */
/*                                                                                      */
/*  It must export the following functions using the following interface or a C++       */
/*  interface inheriting from IUnknown and including similar functions.                 */
/*‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî‚Äî*/

/* The Contextual Menu Manager will only load CFPlugIns of type kContextualMenuTypeID
#define kContextualMenuTypeID ( CFUUIDGetConstantUUIDWithBytes( NULL, \
  0x2F, 0x65, 0x22, 0xE9, 0x3E, 0x66, 0x11, 0xD5, \
  0x80, 0xA7, 0x00, 0x30, 0x65, 0xB3, 0x00, 0xBC ) )
  2F6522E9-3E66-11D5-80A7-003065B300BC */

/* Contextual Menu Plugins must implement this Contexual Menu Plugin Interface
#define kContextualMenuInterfaceID    ( CFUUIDGetConstantUUIDWithBytes( NULL, \
  0x32, 0x99, 0x7B, 0x62, 0x3E, 0x66, 0x11, 0xD5, \
  0xBE, 0xAB, 0x00, 0x30, 0x65, 0xB3, 0x00, 0xBC ) )
  32997B62-3E66-11D5-BEAB-003065B300BC */

/*
#define CM_IUNKNOWN_C_GUTS \
   void *_reserved; \
 SInt32 (*QueryInterface)(void *thisPointer, CFUUIDBytes iid, void ** ppv); \
   UInt32 (*AddRef)(void *thisPointer); \
 UInt32 (*Release)(void *thisPointer)
*/

/* The function table for the interface
struct ContextualMenuInterfaceStruct
{
    CM_IUNKNOWN_C_GUTS;
    OSStatus ( *ExamineContext )(
          void*               thisInstance,
          const AEDesc*       inContext,
         AEDescList*         outCommandPairs );
 OSStatus ( *HandleSelection )(
         void*               thisInstance,
          AEDesc*             inContext,
         SInt32              inCommandID );
 void ( *PostMenuCleanup )(
         void*               thisInstance );
};
typedef struct ContextualMenuInterfaceStruct ContextualMenuInterfaceStruct;
*/

-(void)executeCMPlugin:(CFURLRef)inPluginURLRef submenuPath:(CFURLRef)inSubmenuPath itemName:(CFStringRef)inItemName prefersText:(Boolean)prefersTextContext
{
	OSStatus err = noErr;
	ContextualMenuInterfaceStruct **interface = NULL;
	CFStringRef errorBezelName = NULL;
	AEDesc contextDesc = {typeNull, NULL};
	AEDescList menuItemsList = {typeNull, NULL};

#if _DEBUG_
	printf("Shortcut Observer -> Entering ExecuteCMPlugin\n");
#endif					

	if(inPluginURLRef == NULL)
	{
#if _DEBUG_
		printf("Shortcut Observer->ExecuteCMPlugin. NULL plugin URL passed\n");
#endif					
		return;
	}

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
		printf("Shortcut Observer->ExecuteCMPlugin. Could not load the plugin\n");
		errorBezelName = CFSTR("CannotLoad");
		goto Cleanup;
	}

	err = AECreateList(NULL, 0, false, &menuItemsList);

#if _DEBUG_
	if(err != noErr)
		printf("Shortcut Observer->ExecuteCMPlugin. AECreateList returned error\n");
#endif
			
	if(err == noErr)
	{
		CFObj<CFStringRef> cfProcessName;
		ProcessSerialNumber frontProcess = {0,0};
		err = GetFrontProcess(&frontProcess);
		if(err == noErr)
			err = CopyProcessName (&frontProcess, &cfProcessName);
        
        NSString *processName = CFBridgingRelease(cfProcessName.Detach());
        
		err = [self createContext: &contextDesc forFrontApp:processName frontAppPSN:&frontProcess prefersText:prefersTextContext];//ignore error and go with null context
		if( (contextDesc.descriptorType == typeNull) || (contextDesc.dataHandle == NULL) )
		{
			err = [self createContext: &contextDesc forFrontApp:processName frontAppPSN:&frontProcess prefersText:!prefersTextContext];//try the other context if current result is null
		}

#if _DEBUG_
		printf("Shortcut Observer->ExecuteCMPlugin. CreateFrontAppContext returned error = %d (null context)\n", (int)err);
#endif					
		
		err = (*interface)->ExamineContext(interface, &contextDesc, &menuItemsList );
		if(err == noErr)
		{
#if _DEBUG_
			long itemCount = 0;
			err = AECountItems(&menuItemsList, &itemCount);
			printf("Shortcut Observer->ExecuteCMPlugin. ExamineContext returned item list count=%d\n", (int)itemCount);
#endif					
		
			CFObj<CFMutableArrayRef> menuItemsArray = CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );
			CFObj<CFURLRef> rootLevel = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("/"), kCFURLPOSIXPathStyle, true);
			err = BuildContextualMenuItemsList(&menuItemsList, menuItemsArray, rootLevel);
			
			//dispose early
			err = AEDisposeDesc(&menuItemsList);
			AEInitializeDescInline(&menuItemsList);

			SInt32 foundCommandID = 0;
			Boolean isFound = FindMenuItem(menuItemsArray, inSubmenuPath, inItemName, &foundCommandID);

			if(isFound)
			{
#if _DEBUG_
				printf("Shortcut Observer->ExecuteCMPlugin, about to call HandleSelection\n");
#endif

				CFPreferencesAppSynchronize( kShortcutsIdentifier );
				CFObj<CFStringRef> bezelImageName = (CFStringRef)CFPreferencesCopyAppValue( CFSTR("BEZEL_IMAGE"), kShortcutsIdentifier );
				if( (bezelImageName != nullptr) && (CFGetTypeID(bezelImageName) != CFStringGetTypeID()) )
				{// not a string
					bezelImageName.Adopt(nullptr);
				}

				if(bezelImageName != nullptr)
				{
					ShowBezelWindow((__bridge NSString *)inItemName, nil, (__bridge NSString *)bezelImageName.Get(), @"Bezel Images" );
				}

				(*interface)->HandleSelection(interface, &contextDesc, foundCommandID );
			}
			else
			{
#if _DEBUG_
				printf("Shortcut Observer->ExecuteCMPlugin, Could not find menu item\n");
#endif
				errorBezelName = CFSTR("NotActive");
			}

			(*interface)->PostMenuCleanup(interface);
		}
		else
		{
			errorBezelName = CFSTR("PluginError");
#if _DEBUG_
			printf("Shortcut Observer -> ExecuteCMPlugin -> ExamineContext returned error\n");
#endif
		}
		
		if(contextDesc.dataHandle != NULL)
			AEDisposeDesc(&contextDesc);
		
		if(menuItemsList.dataHandle != NULL)
			AEDisposeDesc(&menuItemsList);
	}

Cleanup:
	if(errorBezelName != NULL)
		ShowErrorWindow(inItemName, errorBezelName);
}

-(void)doShowMenu
{
	NSPoint mouseScreenLoc = [NSEvent mouseLocation];
	/*BOOL itemSelected =*/ [mCMItemsMenu popUpMenuPositioningItem:NULL atLocation:mouseScreenLoc inView:NULL];
	
}

- (void)showContextualMenu:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	if(mCMItemsMenu != NULL) //currently showing the menu
	{
#if _DEBUG_
		printf("ShortcutsObserverDelegate->showContextualMenu. currently showing the menu. exiting...\n");
#endif
		return;
	}

	@try
	{
		OSStatus err;
		//NSLog(@"ShortcutsObserverDelegate: showContextualMenu invoked");
		
		mCMItemsMenu = [[NSMenu alloc] initWithTitle:@"Classic Contextual Menu"];
		[mCMItemsMenu setDelegate:self];//for notification when it closes. this works in 10.5 or higher

		if(mContextDesc.dataHandle != NULL)
			AEDisposeDesc(&mContextDesc);
		AEInitializeDescInline(&mContextDesc);

		Boolean prefersTextContext = true;
		CFObj<CFStringRef> processName;
		ProcessSerialNumber frontProcess = {0, kCurrentProcess};
		
		ShowHideProcess ( &frontProcess, false); //hide ourselves (services server just made us a front app)
		
		//now get whatever process came back to front
		err = GetFrontProcess(&frontProcess);
		if(err == noErr)
		{
			err = CopyProcessName (&frontProcess, &processName);
			if( (err == noErr) && (kCFCompareEqualTo == CFStringCompare(processName, CFSTR("Finder"), 0)) )
				prefersTextContext = false;
		}

		if(pboard != NULL)
		{
			err = -1;
			
			if(prefersTextContext)
			{
				NSArray *supportedTextTypes = [NSArray arrayWithObjects: NSPasteboardTypeString, nil];
				NSString *bestType = [pboard availableTypeFromArray:supportedTextTypes];
				if(bestType != NULL)
				{
					NSString *selectionString = [pboard stringForType:NSPasteboardTypeString];
					err = CreateUniTextDescFromCFString((__bridge CFStringRef)selectionString, &mContextDesc);
				}
			}

			if(err != noErr)//also will enter here if prefersTextContext == false
			{//try file names
				NSArray *supportedFileTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];
				NSString *bestType = [pboard availableTypeFromArray:supportedFileTypes];
				if(bestType != NULL)
				{
					id resultList = [pboard propertyListForType:NSFilenamesPboardType];
					if([resultList isKindOfClass:[NSArray class]])
					{
						[self createAEListForFiles:(NSArray *)resultList];
					}
				}
				else if(!prefersTextContext)//we don't have file paths and did not try text yet: do it now
				{
					NSArray *supportedTextTypes = [NSArray arrayWithObjects: NSPasteboardTypeString, nil];
					NSString *bestType = [pboard availableTypeFromArray:supportedTextTypes];
					if(bestType != NULL)
					{
						NSString *selectionString = [pboard stringForType:NSPasteboardTypeString];
						err = CreateUniTextDescFromCFString((__bridge CFStringRef)selectionString, &mContextDesc);
					}
				}
			}
		}
		else
		{
            NSString * __weak frontAppName = (__bridge NSString *)processName.Get();
			err = [self createContext: &mContextDesc forFrontApp:frontAppName frontAppPSN:&frontProcess prefersText:prefersTextContext];//ignore error and go with null context
			if( (mContextDesc.descriptorType == typeNull) || (mContextDesc.dataHandle == NULL) )
			{
				err = [self createContext: &mContextDesc forFrontApp:frontAppName frontAppPSN:&frontProcess prefersText:!prefersTextContext];//try the other context if current result is null
			}
		}

		[self populateContextualMenu:mCMItemsMenu forContext:&mContextDesc];

		NSInteger itemCount = [mCMItemsMenu numberOfItems];
		if(itemCount == 0)
		{//nothing to show
			mCMItemsMenu = NULL;

			if(mContextDesc.dataHandle != NULL)
				AEDisposeDesc(&mContextDesc);

			return;
		}

//		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
//		[notificationCenter addObserver:self selector:@selector(menuDidEndTrackingNotification:) name:NSMenuDidEndTrackingNotification object:mCMItemsMenu];
//		[notificationCenter addObserver:self selector:@selector(menuWillSendActionNotification:) name:NSMenuWillSendActionNotification object:mCMItemsMenu];

		{
			[mCMItemsMenu setAllowsContextMenuPlugIns:NO];//we don't any CM items from the system, we built our own
			//delay showing the menu to flush the mouse event which seems to dismiss the newly shown menu in macOS Sierra
			[self performSelector:@selector(doShowMenu) withObject:nil afterDelay:0.1];
		}

	}
	@catch (NSException *localException)
	{
		NSLog(@"ShortcutsObserverDelegate received exception: %@", localException);
	}
}

- (void)populateContextualMenu:(NSMenu *)menu forContext:(AEDesc *)contextDesc
{
	int i;
	if( (mPluginList == NULL) || (contextDesc == NULL) )
		return;

	CFIndex	theCount = CFArrayGetCount(mPluginList);
	
	//build menu for all plugins as it would be normally done by cm manager
	for(i = 0; i < theCount; i++)
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(mPluginList, i);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == CFURLGetTypeID()) )
		{
			CFURLRef onePluginURL = (CFURLRef)theItem;
			[self buildMenu:menu forPlugin:onePluginURL withContext: contextDesc];
		}
	}
}

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
	
	AEDescList menuItemsList;
	AEInitializeDescInline(&menuItemsList);
	err = AECreateList(NULL, 0, false, &menuItemsList);
	if(err == noErr)
	{
		err = (*interface)->ExamineContext(interface, contextDesc, &menuItemsList );
		if(err == noErr)
		{
			//recursive menu builder
			CFObj<CFURLRef> rootLevel = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("/"), kCFURLPOSIXPathStyle, true);
			err = [self buildMenuLevel:inMenu
						forPlugin:(CFURLRef)inPluginURLRef
						submenuPath:rootLevel
						forAElist: &menuItemsList
						usingTextContext: (contextDesc->descriptorType == typeUnicodeText) ? true : false];
		}
		
		err = AEDisposeDesc(&menuItemsList);
	}

}

- (OSStatus)buildMenuLevel:(NSMenu *)inMenu forPlugin:(CFURLRef)inPluginURLRef
							submenuPath:(CFURLRef)inSubmenuPath forAElist:(AEDescList*)inMenuItemsList
							usingTextContext: (Boolean)inPrefersText
{
	long itemCount = 0;
	SInt32 oneCommandID = 0;
	UInt32 oneMenuAttribs = 0;
	UInt32 oneMenuModifiers = kMenuNoModifiers;
	Boolean isSubmenu = false;
	AEDescList submenuList;
	AEInitializeDescInline(&submenuList);
	Boolean previousItemWasDynamic = false;

	OSStatus err = AECountItems(inMenuItemsList, &itemCount);
	if(err != noErr)
		return err;

	NSString *keyArray[2];
	id valueArray[2];
	NSColor *redColor = [NSColor redColor];
	keyArray[0] = NSForegroundColorAttributeName;
	valueArray[0] = redColor;

	NSFont *sysFont = [NSFont menuFontOfSize: [NSFont systemFontSize] ];
	keyArray[1] = NSFontAttributeName;
	valueArray[1] = sysFont;

#if 0
	NSDictionary *redMenuTextAttr = [NSDictionary dictionaryWithObjects:valueArray forKeys:keyArray count:2];
#endif

	SInt32 i;
	for(i = 1; i <= itemCount; i++)
	{
		// Get nth item in the list
		AEDesc oneItem;
		AEInitializeDescInline(&oneItem);
		AEKeyword theKeyword;
		err = AEGetNthDesc(inMenuItemsList, i, typeWildCard, &theKeyword, &oneItem);
		if(err != noErr)
			continue;

		if( AECheckIsRecord(&oneItem) )
		{
			oneCommandID = 0;
			oneMenuAttribs = 0;
			oneMenuModifiers = kMenuNoModifiers;
			isSubmenu = false;
			submenuList.descriptorType = typeNull;
			submenuList.dataHandle = NULL;

			CFObj<CFStringRef> oneMenuName;

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
                    NSString * __weak menuName = (__bridge NSString *)oneMenuName.Get();
					menuItem = (NSMenuItem*)[inMenu addItemWithTitle:menuName action:@selector(cmMenuItemSelected:) keyEquivalent:@""];
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
                        NSString * __weak menuName = (__bridge NSString *)oneMenuName.Get();
						NSMenu *subMenu = [[NSMenu alloc] initWithTitle:menuName];
						[inMenu setSubmenu:(NSMenu *)subMenu forItem:menuItem];
						CFObj<CFURLRef> newPath = CFURLCreateCopyAppendingPathComponent(
											kCFAllocatorDefault,
											inSubmenuPath,
											oneMenuName,
											true);
						err = [self buildMenuLevel:subMenu forPlugin:inPluginURLRef
													//itemList:ioList
													submenuPath:newPath
													forAElist: &submenuList
													usingTextContext: inPrefersText];//recursive digger
					}
					else
					{//good, add this item to our array
						CFObj<CFStringRef> submenuPathStr = CFURLCopyFileSystemPath(inSubmenuPath, kCFURLPOSIXPathStyle);//needs to be released
						CFObj<CFStringRef> currentPluginName = CFURLCopyLastPathComponent(inPluginURLRef);//needs to be released

#if 0
						//find if it has hotkey assigned
						CFIndex keyModifiers = 0;
						CFIndex keyCode = 0;
						CFObj<CFStringRef> keyChar;
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
							NSAttributedString *redStr = [[NSAttributedString alloc] initWithString:(NSString*)oneMenuName attributes:redMenuTextAttr];
							[redStr autorelease];
							[menuItem setAttributedTitle:redStr];
						}
#endif
						
						CFObj<CFMutableDictionaryRef> theDict = CFDictionaryCreateMutable(
											kCFAllocatorDefault,
											0,
											&kCFTypeDictionaryKeyCallBacks,
											&kCFTypeDictionaryValueCallBacks);
						if(theDict != nullptr)
						{
							CFDictionarySetValue(theDict, CFSTR("PLUGIN_URL"), inPluginURLRef);
							CFDictionarySetValue(theDict, CFSTR("NAME"), oneMenuName);
							if(submenuPathStr != NULL)
								CFDictionarySetValue(theDict, CFSTR("SUBMENU"), submenuPathStr);//retained

							CFObj<CFNumberRef> commandID = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &oneCommandID);
							CFDictionarySetValue(theDict, CFSTR("ID"), commandID);//retained
							CFDictionarySetValue(theDict, CFSTR("PREFERS_TEXT_CONTEXT"), inPrefersText ? kCFBooleanTrue : kCFBooleanFalse );
                            menuItem.representedObject = CFBridgingRelease(theDict.Detach());
						}
					}
				}

				previousItemWasDynamic = ((oneMenuAttribs & kMenuItemAttrDynamic) != 0);
			}

			if(submenuList.dataHandle != NULL)
				AEDisposeDesc(&submenuList);
			
			AEDisposeDesc(&oneItem);
		}
	}
	return err;
}

//called when user selects the menu item
- (void)cmMenuItemSelected:(id)sender
{
#if _DEBUG_
	printf("ShortcutsObserverDelegate->cmMenuItemSelected\n");
#endif
	//NSLog(@"ShortcutsObserverDelegate: cmMenuItemSelected:");

	//we don't want the timer to do the cleanup. we do it immediately after we are done executing this item
	if(mPostMenuCleanupTimer != NULL)
	{
		[mPostMenuCleanupTimer invalidate];
		mPostMenuCleanupTimer = nil;
	}

	NSMenuItem *menuItem = (NSMenuItem *)sender;
	SInt32 cmItemCommandID = 0;
	id theResult = nil;
	ContextualMenuInterfaceStruct **interface = NULL;

	NSDictionary *menuItemInfo = menuItem.representedObject;
	if(![menuItemInfo isKindOfClass:NSDictionary.class])
    {
        goto Cleanup;
    }
    
    theResult = menuItemInfo[@"PLUGIN_URL"];
    if(![theResult isKindOfClass:NSURL.class])
    {
        goto Cleanup;
    }

	if(mLoadedPluginChain != NULL)
    {
        interface = FindLoadedPlugin(mLoadedPluginChain, (__bridge CFURLRef)theResult);
    }
    
	if(interface == NULL)//this must be a plug-in already loaded
    {
        goto Cleanup;
    }
    
    theResult = menuItemInfo[@"ID"];
    if([theResult isKindOfClass:NSNumber.class])
    {
        cmItemCommandID = (SInt32)((NSNumber *)theResult).intValue;
        
    }

	//Note:
	//if you cancel menu tracking before HandleSelection,
	//it will trigger  PostMenuCleanup prematurely

	(*interface)->HandleSelection(interface, &mContextDesc, cmItemCommandID );

Cleanup:

	if(mContextDesc.dataHandle != NULL)
		AEDisposeDesc(&mContextDesc);

//	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
//	[notificationCenter removeObserver:self];

//	[mCMItemsMenu cancelTracking]; //will trigger menuDidClose and in turn postMenuCleanup
	[self postMenuCleanup];
}

//- (void)menuDidEndTrackingNotification:(NSNotification *)inNotification
//{
//	NSLog(@"ShortcutsObserverDelegate: menuDidEndTrackingNotification:");
//}

//- (void)menuWillSendActionNotification:(NSNotification *)inNotification
//{
//	NSLog(@"ShortcutsObserverDelegate: menuWillSendActionNotification:");
//}

//- (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item
//{
//	NSLog(@"ShortcutsObserverDelegate: menu:willHighlightItem:%@", item);
//}

//called then menu is closed. this is 10.5 or higher
- (void)menuDidClose:(NSMenu *)menu
{
#if _DEBUG_
	printf("ShortcutsObserverDelegate->menuDidClose\n");
#endif
	//NSLog(@"ShortcutsObserverDelegate: menuDidClose:");

//it seems that the only solution is to start a timer here to do the cleanup
//this method gets called before cmMenuItemSelected
//at this point we don't know if any item will be selected or not
//if we get cmMenuItemSelected:, we should remove timer and do the immediate cleanup after execution
	mPostMenuCleanupTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)1.0 target:self selector:@selector(postMenuCleanup) userInfo:NULL repeats:NO];  
}


//call PostMenuCleanup() for all loaded plug-ins
-(void)postMenuCleanup
{
#if _DEBUG_
	printf("ShortcutsObserverDelegate->postMenuCleanup\n");
#endif

	if(mPostMenuCleanupTimer != NULL)
	{
		[mPostMenuCleanupTimer invalidate];
		mPostMenuCleanupTimer = NULL;
	}
	
    mCMItemsMenu = NULL;

	ContextualMenuInterfaceStruct **interface;
	LoadedPlugin* currPlug = mLoadedPluginChain;
	while(currPlug != NULL)
	{
		if(currPlug->interface != NULL)
		{
			interface = currPlug->interface;
			(*interface)->PostMenuCleanup(interface);
		}
		currPlug = currPlug->prevPlugin;
	}
}

-(void)createAEListForFiles:(NSArray *)inFileNames
{
	NSUInteger count = [inFileNames count];
	if(count == 0)
		return;
	
	if((mContextDesc.descriptorType != typeNull) && (mContextDesc.dataHandle != NULL))
		AEDisposeDesc(&mContextDesc);
	AEInitializeDescInline(&mContextDesc);

	OSStatus err = AECreateList( NULL, 0, false, &mContextDesc );
	
	int aeItemIndex = 1;
	for (NSUInteger i = 0; i < count; i++)
	{
		NSString *aFile = [inFileNames objectAtIndex:i];
		FSRef oneRef;
		memset(&oneRef, 0, sizeof(oneRef));
		BOOL isOK = [self getFSRefFromPath:aFile toRef: &oneRef];
		if(isOK)
		{
			AEDesc aliasDesc;
			AEInitializeDescInline(&aliasDesc);
			err = [self createAliasDesc: &oneRef toAlias: &aliasDesc];
			if(err == noErr)
			{
				if(err == noErr)
				{
					err = AEPutDesc( &mContextDesc, aeItemIndex, &aliasDesc );
					if(err == noErr)
						aeItemIndex++;
				}

				AEDisposeDesc(&aliasDesc);
			}
		}
	}
}


- (BOOL)getFSRefFromPath:(NSString *)inPath toRef: (FSRef *)ioRef
{
    if((inPath == NULL) || (ioRef == NULL))
        return NO;

    CFObj<CFURLRef> urlRef = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)inPath, kCFURLPOSIXPathStyle, false);
    if(urlRef != NULL)
    {
        Boolean isOK = CFURLGetFSRef(urlRef, ioRef);
		return isOK;
    }
    return NO;
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


@end //end of ShortcutsObserverDelegate
