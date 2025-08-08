//
//  StatusController.mm
//  Shortcuts

#import <ServiceManagement/ServiceManagement.h>
#import "StatusController.h"
#include <CoreServices/CoreServices.h>
#include <Carbon/Carbon.h>
#include "CocoaBezelWindow.h"
#include "CFObj.h"

#define SHORTCUTS_IDENTIFIER CFSTR("com.abracode.Shortcuts")
CFStringRef kShortcutObserverApp = CFSTR("ShortcutObserver.app");
CFStringRef kShortcutObserverAppBundleIdentifier = CFSTR("com.abracode.ShortcutObserver");
const FourCharCode kObserverCreatorCode = 'AbSO';

CGImageRef ReadImage(CFBundleRef inBundle, CFStringRef inSubFolder, CFStringRef inBackgroundPictureName);
//pascal void AutoCloseTimerAction(EventLoopTimerRef inTimer, void *timeData);
CFStringRef kStartItemsArrayID = NULL;
CFStringRef kLoginWindowIdentifier = NULL;

BOOL
IsAppAddedToLoginItems(NSString *appBundleIdentifier)
{
    BOOL isAdded  = NO;

    if (@available(macOS 13.0, *))
    {
        SMAppService *service = [SMAppService loginItemServiceWithIdentifier:appBundleIdentifier];
        if(service != nil)
        {
            SMAppServiceStatus serviceStatus = service.status;
            isAdded = (serviceStatus == SMAppServiceStatusEnabled);
        }
    }
    else
    {
        CFArrayRef allJobDictionaries = SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
        if(allJobDictionaries == nullptr)
            return NO;
        
        NSArray *allJobs = (NSArray *)CFBridgingRelease(allJobDictionaries);
        for(NSDictionary* oneJob in allJobs)
        {
            if([appBundleIdentifier isEqualToString:[oneJob objectForKey:@"Label"]])
            {
                isAdded = [[oneJob objectForKey:@"OnDemand"] boolValue];
                break;
            }
        }
    }
	return isAdded;
}

@implementation StatusController

- (id)init
{
    if (![super init])
        return nil;
	
	mIsObserverRunning = NO;
	mIsAddedToLoginItems = NO;
	kStartItemsArrayID = CFSTR("AutoLaunchedApplicationDictionary");
	kLoginWindowIdentifier = CFSTR("loginwindow");

	return self;
}

- (void)awakeFromNib
{
	NSBundle *appBundle = [NSBundle mainBundle];
	NSURL *appURL = [appBundle bundleURL];
	self.observerURL = [appURL URLByAppendingPathComponent:@"Contents/Library/LoginItems/ShortcutObserver.app"];

	mIsObserverRunning = [self isObserverRunning];
	[self observerStatusChanged];
	
    mIsAddedToLoginItems = IsAppAddedToLoginItems((__bridge NSString *)kShortcutObserverAppBundleIdentifier);
	[self loginItemsStatusChanged];

	NSMenu *bezelImagesMenu = [mBezelPopup menu];
	[bezelImagesMenu setDelegate:self];
	[bezelImagesMenu setAutoenablesItems:YES];
	[self populateBezelImageMenu:bezelImagesMenu];

	CFObj<CFPropertyListRef> resultRef = CFPreferencesCopyAppValue(CFSTR("BEZEL_IMAGE"), SHORTCUTS_IDENTIFIER);
	if(resultRef == nullptr)
	{
		[mBezelPopup selectItemWithTitle: NSLocalizedString(@"None", @"")];
	}
	else
	{
		if( CFGetTypeID(resultRef) == CFStringGetTypeID() )
		{
            NSString * __weak resultStr = (__bridge NSString*)resultRef.Get();
			[mBezelPopup selectItemWithTitle:resultStr];
		}
	}
}

- (void)updateObserverStatus
{
	BOOL isObserverRunning = [self isObserverRunning];
	if(mIsObserverRunning != isObserverRunning)
	{
		mIsObserverRunning = isObserverRunning;
		[self observerStatusChanged];
	}
	
	BOOL isAddedToLoginItems = IsAppAddedToLoginItems((__bridge NSString *)kShortcutObserverAppBundleIdentifier);
	if(mIsAddedToLoginItems != isAddedToLoginItems)
	{
		mIsAddedToLoginItems = isAddedToLoginItems;
		[self loginItemsStatusChanged];
	}
}
- (void)observerStatusChanged
{
	NSImage *myImage = NULL;
	if(mIsObserverRunning)
	{
		[mObserverButton setTitle:NSLocalizedString(@"Stop", @"")];
		[mObserverText setStringValue:NSLocalizedString(@"Stop_ShortcutObserver", @"")];

		myImage = [NSImage imageNamed: @"faster.tiff"];
	}
	else
	{
	    [mObserverButton setTitle:NSLocalizedString(@"Start", @"")];
		[mObserverText setStringValue:NSLocalizedString(@"Start_ShortcutObserver", @"")];

		myImage = [NSImage imageNamed: @"NSApplicationIcon"];
	}
	
	if(myImage != NULL)
	{
		[NSApp setApplicationIconImage: myImage];
	}
}

- (void)loginItemsStatusChanged
{
	if(mIsAddedToLoginItems)
	{
		[mLoginButton setTitle:NSLocalizedString(@"Remove", @"")];
		[mLoginText setStringValue:NSLocalizedString(@"Remove_LoginItem", @"")];
	}
	else
	{
	    [mLoginButton setTitle:NSLocalizedString(@"Add", @"")];
		[mLoginText setStringValue:NSLocalizedString(@"Add_LoginItem", @"")];
	}
}

- (IBAction)startOrStopObserver:(id)sender
{
	if(mIsObserverRunning)
		[self quitShortcutObserver];
	else
		[self startShortcutObserver];
	[self observerStatusChanged];
}

- (IBAction)addOrRemoveLoginItem:(id)sender
{
    BOOL isOK = NO;
    if (@available(macOS 13.0, *))
    {
        SMAppService *service = [SMAppService loginItemServiceWithIdentifier:(__bridge NSString *)kShortcutObserverAppBundleIdentifier];
        if(service != nil)
        {
            SMAppServiceStatus serviceStatus = service.status;
            BOOL isAdded = (serviceStatus == SMAppServiceStatusEnabled);
            if(isAdded)
            {
                isOK = [service unregisterAndReturnError:NULL];
            }
            else
            {
                isOK = [service registerAndReturnError:NULL];
            }
        }
    }
    else
    {
        Boolean enable = !mIsAddedToLoginItems;
        isOK = SMLoginItemSetEnabled(kShortcutObserverAppBundleIdentifier, enable);
    }
    
    [self performSelector:@selector(updateObserverStatus) withObject:nil afterDelay:0.5];
}

- (IBAction)reviewSystemPrefsAccessibility:(id)sender
{
	NSURL *prefsScriptURL = [[NSBundle mainBundle] URLForResource:@"RevealAccessibilityPrefs" withExtension:@"scpt"];
	NSAppleScript *myScript = [[NSAppleScript alloc] initWithContentsOfURL:prefsScriptURL error:nil];
	if(myScript != nil)
		[myScript executeAndReturnError:nil];
}

- (BOOL)isObserverRunning
{
    NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:(__bridge NSString *)kShortcutObserverAppBundleIdentifier];
    return ([runningApps count] > 0);
}

- (void)startShortcutObserver
{
	//[[NSWorkspace sharedWorkspace] openURL:self.observerURL];
	OSStatus err = fnfErr;
	if(self.observerURL != nil)
		err = LSOpenCFURLRef((__bridge CFURLRef)self.observerURL, nullptr);

	if(err != noErr)
	{
		NSLog(@"An error ocurred while launching ShortcutObserver.app");
		return;
	}

	//now the observer should be starting
	int i;
	for(i = 1; i <= 10; i++)
	{//we only try 10 times and then give up
		mIsObserverRunning = [self isObserverRunning];
		if(mIsObserverRunning == YES)
			break;
		sleep(1);
	}
}

- (void)quitShortcutObserver
{
/*AppleScript stuff takes too long to process. use raw AppleEvent
	NSAppleScript *myScript = [[NSAppleScript alloc] initWithSource: @"tell app \"ShortcutObserver\" to quit"];
	if(myScript != nil)
	{
		[myScript autorelease];
		NSDictionary *errorInfo = nil;
		NSAppleEventDescriptor *resultDesc = [myScript executeAndReturnError: &errorInfo];
	}
*/	

	AEDesc appAddress = {typeNull, NULL};
	OSErr err = AECreateDesc(typeApplSignature, &kObserverCreatorCode, sizeof(FourCharCode), &appAddress);
	if(err != noErr)
	{
		NSLog(@"Shortcuts->quitShortcutObserver: AECreateDesc returned error");
		return;
	}
	
	AEDesc appleEvent = {typeNull, NULL};

	err = AECreateAppleEvent(
					kCoreEventClass,
					kAEQuitApplication,
					&appAddress,
					kAutoGenerateReturnID,
					kAnyTransactionID,
					&appleEvent);

	if(appAddress.dataHandle != NULL)
		AEDisposeDesc( &appAddress );

	if(err != noErr)
	{
		NSLog(@"Shortcuts->quitShortcutObserver: AECreateAppleEvent returned error");
		return;
	}
	
	AEDesc aeReply = {typeNull, NULL};
	err = AESend( &appleEvent, &aeReply, kAENoReply,
					kAENormalPriority, kAEDefaultTimeout, NULL, NULL);

	if(aeReply.dataHandle != NULL)
		AEDisposeDesc( &aeReply );

	if(appleEvent.dataHandle != NULL)
		AEDisposeDesc( &appleEvent );

	//now the observer should be quitting
	int i;
	for(i = 1; i <= 10; i++)
	{//we only try 10 times and then give up
		mIsObserverRunning = [self isObserverRunning];
		if(mIsObserverRunning == NO)
			break;
		sleep(1);
	}
	
	//if it refuses to quit, kill it
//	KillProcess(const ProcessSerialNumber * inProcess) 
}


- (void)windowDidBecomeKey:(NSNotification *) __unused aNotification
{
	[self updateObserverStatus];
}

-(void)populateBezelImageMenu:(NSMenu *)menu
{
	int theCount = [menu numberOfItems];
	int i;
	for(i = (theCount-1); i >= 0; i--)
	{
		[menu removeItemAtIndex:i];
	}
	
	NSMenuItem *menuItem = (NSMenuItem*)[menu addItemWithTitle: NSLocalizedString(@"None",@"") action:@selector(bezelMenuItemSelected:) keyEquivalent:@""];
	if(menuItem != nil)
	{
		[menuItem setTarget:self];
		[menuItem setState:NSOffState];
		[menuItem setEnabled:YES];
	}

	CFObj<CFBundleRef> observerBundle;
	if(_observerURL != nil)
		observerBundle.Adopt(CFBundleCreate( kCFAllocatorDefault, (CFURLRef)self.observerURL));
	if(observerBundle != nullptr)
	{
		CFObj<CFArrayRef> imageURLs = CFBundleCopyResourceURLsOfType( observerBundle, CFSTR("png"), CFSTR("Bezel Images") );
		if( imageURLs != nullptr )
		{
			CFIndex itemCount = CFArrayGetCount(imageURLs);
			CFIndex i;
			for( i = 0; i < itemCount; i++ )
			{
				CFTypeRef theItem = CFArrayGetValueAtIndex(imageURLs, i);
				if( (theItem != nullptr) && (CFGetTypeID(theItem) == CFURLGetTypeID()) )
				{
					CFURLRef oneURL = (CFURLRef)theItem;
					CFObj<CFURLRef> newURL = CFURLCreateCopyDeletingPathExtension( kCFAllocatorDefault, oneURL );
					NSString *oneName = CFBridgingRelease(CFURLCopyLastPathComponent(newURL));
					menuItem = (NSMenuItem*)[menu addItemWithTitle:oneName action:@selector(bezelMenuItemSelected:) keyEquivalent:@""];
					if(menuItem != nil)
					{
						[menuItem setTarget:self];
						[menuItem setState:NSOffState];
						[menuItem setEnabled:YES];
					}
				}
			}
		}
	}
}

- (IBAction)bezelMenuItemSelected:(id)sender
{
	NSMenuItem *menuItem = (NSMenuItem *)sender;
	if(menuItem == NULL)
		return;
	
	NSString *noneStr = NSLocalizedString(@"None", @"");
	NSString *itemStr = [menuItem title];
	if( [itemStr isEqualToString: noneStr] )
	{
		itemStr = NULL;
	}

	CFPreferencesSetAppValue( CFSTR("BEZEL_IMAGE"), (CFPropertyListRef)itemStr, SHORTCUTS_IDENTIFIER );
	CFPreferencesAppSynchronize(SHORTCUTS_IDENTIFIER);
	if( itemStr != NULL )
		ShowBezelWindow( NSLocalizedString(@"Command Test", @""), self.observerURL, itemStr, @"Bezel Images" );
}


@end

#pragma mark -


CGImageRef
ReadImage(CFBundleRef inBundle, CFStringRef inSubFolder, CFStringRef inBackgroundPictureName)
{
	if(inBundle == nullptr)
		inBundle = CFBundleGetMainBundle();

	CFObj<CFURLRef> url = CFBundleCopyResourceURL(inBundle, inBackgroundPictureName, CFSTR("png"), inSubFolder);
	if( url == nullptr )
		return nullptr;

	CGImageRef outImage = nullptr;
	CFObj<CGDataProviderRef> provider = CGDataProviderCreateWithURL(url);
	if(provider != nullptr)
		outImage = CGImageCreateWithPNGDataProvider(provider, NULL, false,  kCGRenderingIntentDefault);

	return outImage;
}

