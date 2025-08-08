//
//  CocoaBezelWindow.mm
//  ShortcutObserver

#import "CocoaBezelWindow.h"
#import <Cocoa/Cocoa.h>

void BezelWindowAutoCloseCallBack(CFRunLoopTimerRef timer, void* info)
{
#pragma unused (timer)
	NSWindow *theWindow = (NSWindow *)info;
	if(theWindow == NULL)
		return;

	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:theWindow, NSViewAnimationTargetKey,
							  NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
							  nil];
		
	NSViewAnimation *fadeOutAnimation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:dict]];
	[fadeOutAnimation autorelease];//luckily animation lives on until it is done
	[fadeOutAnimation setAnimationBlockingMode:NSAnimationNonblocking];
	[fadeOutAnimation startAnimation];

	[theWindow autorelease];//luckily the window is retained by animation and will be gone only when animation is done
}


void
ShowBezelWindow(CFStringRef inText, CFURLRef inObserverURL, CFStringRef inImageName, CFStringRef inSubFolder)
{
	if( (inImageName == NULL) || (inText == NULL) )
		return;

	NSBundle *appBundle = nil;
	if(inObserverURL == nullptr)
		appBundle = [NSBundle mainBundle];
	else
		appBundle = [NSBundle bundleWithURL:(NSURL *)inObserverURL];

	if(appBundle == nil)
		return;

	NSString *imgPathStr = [appBundle pathForResource:(NSString *)inImageName ofType:@"png" inDirectory:(NSString *)inSubFolder];
	if(imgPathStr == nil)
		return;

	NSImage *windowImage = [[NSImage alloc] initWithContentsOfFile:imgPathStr];
	[windowImage autorelease];
	NSSize imgSize = [windowImage size];
	NSRect windowRect = NSMakeRect(0, 0, imgSize.width, imgSize.height);
	
	NSWindow *overlayWindow = [[NSWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
	[overlayWindow setLevel:kCGOverlayWindowLevel];
	[overlayWindow setHidesOnDeactivate:NO];
	[overlayWindow setOpaque:NO];
	[overlayWindow setBackgroundColor:[NSColor clearColor]];
	NSImageView *imgView = [[NSImageView alloc] initWithFrame:windowRect];
	[imgView setImage:windowImage];
	
	[overlayWindow setContentView:imgView];
	[imgView release];
	
	NSTextField *textLabel = [[NSTextField alloc] initWithFrame:windowRect];
	[[textLabel cell] setLineBreakMode:NSLineBreakByWordWrapping];
	[[textLabel cell] setWraps:YES];
	NSFont *myFont = [NSFont labelFontOfSize:26.0];
	[textLabel setFont:myFont];
	[textLabel setTextColor:[NSColor whiteColor]];
	[textLabel setAlignment:NSCenterTextAlignment];
	[textLabel setStringValue:(NSString *)inText];
//	[textLabel setStringValue:@"Some long text to wrap around"];

	//start with a rect inset on each side
	NSRect refRect;
	refRect.origin.x = 10;
	refRect.origin.y = 0;
	refRect.size.width = windowRect.size.width - 20;
	refRect.size.height = windowRect.size.height;

	NSSize cellSize = [[textLabel cell] cellSizeForBounds:refRect];
	NSRect textFrame;
	textFrame.origin.x = 0;
	textFrame.origin.y = 0;
	textFrame.size.width = cellSize.width + 6;//cell is a little bit inset from control frame
	textFrame.size.height = cellSize.height + 6;
	[textLabel setFrame:textFrame];

	[textLabel setEditable:NO];
	[textLabel setDrawsBackground:NO];
	[textLabel setBezeled:NO];

//center the text view
	NSPoint textPos;
	textPos.x = windowRect.size.width/2 - textFrame.size.width/2;
	textPos.y = windowRect.size.height/2 - textFrame.size.height/2;
	[textLabel setFrameOrigin:textPos];

	[imgView addSubview:textLabel];

	NSScreen *mainScreen = [NSScreen mainScreen];
	NSRect visFrame = [mainScreen visibleFrame];
	
	NSPoint windowOrigin;
	windowOrigin.x = visFrame.origin.x + visFrame.size.width/2 - windowRect.size.width/2;
	windowOrigin.y = visFrame.origin.y + visFrame.size.height/3 - windowRect.size.height/2;
	[overlayWindow setFrameOrigin:windowOrigin];
	[overlayWindow orderFrontRegardless];


	CFRunLoopTimerContext timerContext = {0, overlayWindow, NULL, NULL, NULL};
	CFRunLoopTimerRef autoCloseTimer = CFRunLoopTimerCreate(
											 kCFAllocatorDefault,
											 CFAbsoluteTimeGetCurrent() + 1.0,
											 0,		// interval
											 0,		// flags
											 0,		// order
											 BezelWindowAutoCloseCallBack,
											 &timerContext);
	
	if(autoCloseTimer != NULL)
	{
		CFRunLoopAddTimer(CFRunLoopGetCurrent(), autoCloseTimer, kCFRunLoopCommonModes);
	}
}

