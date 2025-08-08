//
//  HotKeyWindow.h
//  Shortcuts

#import <Cocoa/Cocoa.h>

@interface HotKeyWindow : NSWindow
{
	unsigned int modifiers;
	CFIndex keyCode;
	NSString *keyString;
	IBOutlet NSTextField *mShortcutDisplay;
	IBOutlet NSTextField *mGlyphDisplay;
	IBOutlet NSTextField *mConflictDisplay;
	//some data we need to keep to discover conflicts 
	CFArrayRef mShortcutList;
	CFStringRef mPluginName;
	CFStringRef mSubmenuPath;
	CFStringRef mItemName;
	CFArrayRef mSystemHotKeyArray;
	CFArrayRef mServicesHotKeyArray;
}

- (void)resetHotKey;
- (void)setShortcutList: (CFArrayRef)inList pluginName: (CFStringRef)inPluginName submenuPath: (CFStringRef)inPath menuName: (CFStringRef)inName;
- (void)setHotKey:(CFIndex)inKeyCode withModifiers:(CFIndex)inCarbonModifiers withKeyChar:(CFStringRef)inKeyChar;
- (CFIndex)getCarbonModifiers;
- (void) setModifiersFromCarbonModifiers:(CFIndex)inCarbonModifiers;
- (CFIndex)getKeyCode;
- (CFStringRef)getKeyChar;
- (void)displayShortcut:(NSString*)theKey;
-(NSString *)getSpecialKeyString:(CFIndex)inKeyCode;


@end
