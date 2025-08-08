//
//  main.c
//  Shortcut
//
//  Created by Tom on 2/7/05.
//  Copyright Abracode, Inc. 2005. All rights reserved.
//

#include <Carbon/Carbon.h>

Boolean FindMenuItem(CFArrayRef menuItemsArray, CFURLRef inSubmenuPath, CFStringRef inItemName, SInt32 *outCommandID);
CGImageRef ReadImage(CFBundleRef inBundle, CFStringRef inSubFolder, CFStringRef inBackgroundPictureName);
pascal void AutoCloseTimerAction(EventLoopTimerRef inTimer, void *timeData);


// UnregisterEventHotKey(myRef);
// cmdKey | optionKey | shiftKey | controlKey
/*
void
RegisterShortcut(UInt32 inHotKeyCode, UInt32 inHotKeyModifiers)
{
	EventHotKeyRef shortcutRef = NULL;
	EventHotKeyID myShortcutID;
	myShortcutID.signature = 'Shct';
	myShortcutID.id = 123;

	OSStatus err = RegisterEventHotKey (
						inHotKeyCode,
						inHotKeyModifiers,
						myShortcutID,
						GetApplicationEventTarget(),
						0, //OptionBits inOptions, Currently unused. Pass 0 or face the consequences.
						&shortcutRef);

}



void
TestExecuteOneCommand(CFArrayRef pluginList)
{
	OSStatus		err;
	CFURLRef foundPlugin = NULL;
	CFStringRef myPluginName = CFSTR("OnMyCommandCM.plugin");
	CFStringRef myCommandName = CFSTR("Create New Disk Image...");
	CFURLRef subPathURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("/On My Command/"), kCFURLPOSIXPathStyle, true);

	if(pluginList != NULL)
	{
		CFStringRef oneName = NULL;
		CFIndex	theCount = CFArrayGetCount(pluginList);
		CFIndex i;
		for(i = 0; i < theCount; i++)
		{
			CFTypeRef theItem = CFArrayGetValueAtIndex(pluginList, i);
			if( (theItem != NULL) && (CFGetTypeID(theItem) == CFURLGetTypeID()) )
			{
				CFURLRef onePluginURL = (CFURLRef)theItem;
				oneName = CFURLCopyLastPathComponent(onePluginURL);
				if(oneName != NULL)
				{
					if( kCFCompareEqualTo == CFStringCompare(myPluginName, oneName, 0) )
					{
						foundPlugin = onePluginURL;
					}
					CFRelease(oneName);
				}
			}
			if(foundPlugin != NULL)
				break;
		}
		
		if(foundPlugin != NULL)
		{
			ExecuteCMPlugin(foundPlugin, subPathURL, myCommandName, false);
		}
	}
}
*/

//caller responsible for releasing the result
/*unused:
OSStatus
ExecuteAppleScriptString( CFStringRef inCommand, AEDesc *resultDesc )
{
	OSStatus err = noErr;
	ComponentInstance myOSAComponent;
//	CFStringRef	resultString = NULL;
	AEDesc theCommandDesc = {typeNull, NULL};
//	AEDesc resultDesc = {typeNull, NULL};

	if( (inCommand == NULL) || (resultDesc == NULL) )
		return paramErr;

	if(mOSAComponent == NULL)
		mOSAComponent = OpenDefaultComponent( kOSAComponentType, kOSAGenericScriptingComponentSubtype );

	err = CreateUniTextDescFromCFString(inCommand, &theCommandDesc);

	if(err != noErr)
		goto cleanup;

	err = OSADoScript(
						mOSAComponent,
						&theCommandDesc,
						kOSANullScript,
						typeUnicodeText,
						kOSAModeCanInteract | kOSAModeDisplayForHumans,
						resultDesc);

	if(err != noErr)
	{
		printf("Shortcut Observer->ExecuteAppleScript. OSADoScript returned error: %d\n", (int)err);
		goto cleanup;
	}
	
//	resultString = CreateCFStringFromAEDesc(&resultDesc);

cleanup:

//	if (mOSAComponent != NULL)
//		CloseComponent(mOSAComponent);

	if(theCommandDesc.dataHandle != NULL)
		AEDisposeDesc( &theCommandDesc );
	
	return err;
}
*/

#pragma mark -



//code below is copied to "Shortcuts" source code. needs to be kept in sync

void
ShowBezelWindow(CFStringRef inText, CFStringRef inImageName, CFStringRef inSubFolder)
{
	if( (inImageName == NULL) || (inText == NULL) )
		return;

#ifndef __LP64__
	CGImageRef windowImage = ReadImage( NULL, inSubFolder, inImageName );
	
	if(windowImage == NULL)
		return;

	Rect globalBounds;
	globalBounds.top = globalBounds.left = 0;
	globalBounds.bottom = CGImageGetHeight(windowImage);
	globalBounds.right = CGImageGetWidth(windowImage);

	WindowRef overlayWindow = NULL;
	OSStatus err = CreateNewWindow(
						kOverlayWindowClass,
						kWindowNoShadowAttribute | kWindowStandardHandlerAttribute | kWindowCompositingAttribute,
						&globalBounds, &overlayWindow);
	
	if( (err != noErr) || (overlayWindow == NULL) )
	{
		CGImageRelease(windowImage);
		return;
	}

//	RepositionWindow(overlayWindow, NULL, kWindowCenterOnMainScreen );

	Rect screenRect = {0,0, 768, 1024};
	GetAvailableWindowPositioningBounds ( GetGDevice(), &screenRect);

	GetWindowBounds(overlayWindow, kWindowGlobalPortRgn, &globalBounds);
	short windowHeight = globalBounds.bottom - globalBounds.top;
	short windowWidth = globalBounds.right - globalBounds.left;
	short lowerCenterY = (2 * (screenRect.top + screenRect.bottom)) / 3;

	globalBounds.top = lowerCenterY - windowHeight/2;	
	globalBounds.left = (screenRect.left + screenRect.right)/2 - windowWidth/2;
	
//	SetWindowBounds(overlayWindow, kWindowGlobalPortRgn, &globalBounds);

	MoveWindow(overlayWindow, globalBounds.left, globalBounds.top, false);


	HIViewRef rootView = HIViewGetRoot(overlayWindow);

	HIRect viewBounds;
	err = HIViewGetBounds(rootView, &viewBounds);

	ControlRef imageView = NULL;
	err = HIImageViewCreate(windowImage, &imageView);
	CGImageRelease(windowImage);
	if(imageView != NULL)
	{
		err = HIViewAddSubview(rootView, imageView);
		err = HIViewSetFrame(imageView, &viewBounds);
		HIViewSetVisible(imageView, true);
		//HIImageViewSetAlpha(imageView, 0.7f);
	}

	ControlRef textView = NULL;
	ControlFontStyleRec textStyle;
	RGBColor whiteColor = {0xFFFF, 0xFFFF, 0xFFFF};
	textStyle.flags = kControlUseSizeMask | kControlUseForeColorMask | kControlUseJustMask;
//	textStyle.font;
	textStyle.size = 28;
//	textStyle.style;
//	textStyle.mode;
	textStyle.just = teCenter;
	textStyle.foreColor = whiteColor;
//	textStyle.backColor;	
	
	Rect textBounds = {0,0, 0, 0};
	textBounds.right = (short)viewBounds.size.width - 30;//15 pix margin each side of the window
	textBounds.bottom = 2 * textStyle.size + 10;//make room for 2 lines

	err = CreateStaticTextControl(
			NULL, //window,
			&textBounds,
			inText, //text,
			&textStyle,
			&textView);


/*
	err = HITextViewCreate(
				NULL, 
				0, //OptionBits inOptions
				kTXNReadOnlyMask | kTXNAlwaysWrapAtViewEdgeMask | kTXNMonostyledTextMask |
				kTXNNoTSMEverMask | kTXNNoKeyboardSyncMask | kTXNNoSelectionMask | kTXNDoNotInstallDragProcsMask |
				kTXNDontDrawCaretWhenInactiveMask | kTXNDisableDragAndDropMask,
				&textView);
*/

	if(textView != NULL)
	{
		//HITextViewSetBackgroundColor(textView, NULL);
		SInt16 baseLineOffset = 0;
		err = GetBestControlRect( textView,  &textBounds, &baseLineOffset );

		HIRect textViewBounds;
		CGPoint centerPoint;
		centerPoint.x = viewBounds.origin.x + viewBounds.size.width/2.0;
		centerPoint.y = viewBounds.origin.y + viewBounds.size.height/2.0;
	
		short width = textBounds.right - textBounds.left;
		short height = textBounds.bottom - textBounds.top;

		if(width <= 0)
			width = (short)viewBounds.size.width - 30.0;
		
		if(height <= 0)
			height = 2 * textStyle.size + 10;//fall back to 2 lines

		textViewBounds.origin.x = centerPoint.x - (float)(width/2);
		textViewBounds.size.width = (float)width;
		textViewBounds.origin.y = centerPoint.y - (float)(height/2);;
		textViewBounds.size.height = (float)height;

		err = HIViewAddSubview(rootView, textView);
		err = HIViewSetFrame(textView, &textViewBounds);

//		err = HIViewSetText( textView, CFSTR("Hello World"));
		HIViewSetVisible(textView, true);
	}


	ShowWindow(overlayWindow);
	
	static EventLoopTimerUPP  autoCloseUPP = NULL;
	if(autoCloseUPP == NULL)
		autoCloseUPP = NewEventLoopTimerUPP(AutoCloseTimerAction);
	
	EventLoopTimerRef autocloseTimer = NULL;
	InstallEventLoopTimer(GetCurrentEventLoop(), 1.0, 0.0, autoCloseUPP, overlayWindow, &autocloseTimer);

#else //__LP64__
	CFShow( CFSTR("Carbon bezel window disabled in 64-bit architecture") );
#endif //__LP64__

}

CGImageRef
ReadImage(CFBundleRef inBundle, CFStringRef inSubFolder, CFStringRef inBackgroundPictureName)
{
	CFURLRef url = NULL;
	if(inBundle == NULL)
		inBundle = CFBundleGetMainBundle();

//	CFStringRef debugStr = CFBundleGetIdentifier(inBundle);

	url = CFBundleCopyResourceURL( inBundle, inBackgroundPictureName, CFSTR("png"), inSubFolder );
	
	if( url == NULL )
		return NULL;

	CGImageRef outImage = NULL;
	CGDataProviderRef provider = CGDataProviderCreateWithURL( url );
	if(provider != NULL)
	{
		outImage = CGImageCreateWithPNGDataProvider( provider, NULL, false,  kCGRenderingIntentDefault );
		CGDataProviderRelease( provider );
	}
	CFRelease( url );
	return outImage;
}

#ifndef __LP64__

pascal void AutoCloseTimerAction(EventLoopTimerRef inTimer, void *timeData)
{
	WindowRef theWindow = (WindowRef)timeData;
	if(theWindow != NULL)
	{
		TransitionWindowOptions transOptions;
		transOptions.version = 0;
		transOptions.duration = 0.5;
		transOptions.window = NULL;
		transOptions.userData = NULL;
		TransitionWindowWithOptions(
			theWindow,
			kWindowFadeTransitionEffect,
			kWindowHideTransitionAction,
			NULL, //inBounds,
			false, //inAsync,
			&transOptions);

		DisposeWindow(theWindow);
	}

	RemoveEventLoopTimer(inTimer);
}
#endif //__LP64__
