//
//  HotKeyWindow.m
//  Shortcuts

#import "HotKeyWindow.h"
#include <Carbon/Carbon.h>
#include "ShortcutList.h"

Boolean HasSystemHotKeyConflictForHotKey(CFArrayRef systemHotKeyArray, CFIndex inCarbonModifiers, CFIndex inKeyCode);
Boolean HasServicesHotKeyConflictForHotKey(CFArrayRef servicesHotKeyArray, CFIndex inCarbonModifiers, CFStringRef inKeyString);

const UniChar kCmdGlyph = 0x2318;
const UniChar kOptionGlyph = 0x2325;
const UniChar kControlGlyph = 0x005E;
const UniChar kShiftGlyph = 0x21E7;

typedef struct KeyCodeAndName
{
	CFIndex code;
	NSString *name;
} KeyCodeAndName;

const KeyCodeAndName kSpecialKeys[] = 
{
	{36, @"return"},	
	{48, @"tab"},
	{51, @"delete"},
	{52, @"enter"},//laptop
	{53, @"esc"},
	{71, @"clear"},
	{76, @"enter"},
	{114, @"help"},
	{115, @"home"},
	{117, @"backspace"},
	{119, @"end"},
	{116, @"page up"},
	{121, @"page down"},
	{122, @"F1"},
	{120, @"F2"}, 
	{99, @"F3"}, 
	{118, @"F4"},  
	{96, @"F5"},
	{97, @"F6"},
	{98, @"F7"},
	{100, @"F8"},
	{101, @"F9"},
	{109, @"F10"},
	{103, @"F11"},
	{111, @"F12"},
	{105, @"F13"},
	{107, @"F14"},
	{113, @"F15"},
	{106, @"F16"}
};

typedef struct KeyCodeAndGlyph
{
	CFIndex code;
	UniChar glyph;
} KeyCodeAndGlyph;

KeyCodeAndGlyph kSpecialGlyph[] = 
{
	{123, 0x2190},//left
	{124, 0x2192},//right
	{125, 0x2193},//down
	{126, 0x2191}//up
};

@implementation HotKeyWindow


- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)styleMask backing:(NSBackingStoreType)backingType defer:(BOOL)flag
{
	self = [super initWithContentRect:contentRect styleMask:styleMask backing:backingType defer:flag];
    if (self != NULL)
	{
        // Initialization code here.
		modifiers = 0;
		keyCode = 0;
		_keyString = @"";
		mShortcutList = NULL;
		mPluginName = NULL;
		mSubmenuPath = NULL;
		mItemName = NULL;
		mSystemHotKeyArray = NULL;
		mServicesHotKeyArray = NULL;
    }
    return self;
}

- (void)dealloc
{
	if( mShortcutList != NULL )
		CFRelease( mShortcutList );

	if( mPluginName != NULL )
		CFRelease( mPluginName );

	if( mSubmenuPath != NULL )
		CFRelease( mSubmenuPath );

	if( mItemName != NULL )
		CFRelease( mItemName );

	if( mSystemHotKeyArray != NULL )
		CFRelease(mSystemHotKeyArray);

	if( mServicesHotKeyArray != NULL )
		CFRelease(mServicesHotKeyArray);
}

- (void)resetHotKey
{
	modifiers = 0;
	keyCode = 0;
	self.keyString = @"";

	[self displayShortcut:self.keyString];
//	[mShortcutDisplay setStringValue:@""];
}

- (void)setHotKey:(CFIndex)inKeyCode withModifiers:(CFIndex)inCarbonModifiers withKeyChar:(CFStringRef)inKeyChar
{
	keyCode = inKeyCode;
	[self setModifiersFromCarbonModifiers:inCarbonModifiers];

    self.keyString = nil;

	if(inKeyChar != NULL)
	{
        CFRetain(inKeyChar);
		self.keyString = (NSString*)CFBridgingRelease(inKeyChar);
	}
	
	[self displayShortcut:self.keyString];
}

- (CFIndex)getKeyCode
{
	return keyCode;
}

//retain if you plan to keep it
- (CFStringRef)getKeyChar
{
	return (__bridge CFStringRef)self.keyString;
}

- (CFIndex) getCarbonModifiers
{
   CFIndex outModifiers = 0;

    if((modifiers & NSCommandKeyMask) != 0)
		outModifiers |= cmdKey;

    if((modifiers & NSShiftKeyMask) != 0)
		outModifiers |= shiftKey;	

    if((modifiers & NSAlphaShiftKeyMask) != 0)
		outModifiers |= alphaLock;

    if((modifiers & NSAlternateKeyMask) != 0)
		outModifiers |= optionKey;

    if((modifiers & NSControlKeyMask) != 0)
		outModifiers |= controlKey;

    return outModifiers;
}

- (void) setModifiersFromCarbonModifiers:(CFIndex)inCarbonModifiers
{
	modifiers = 0;

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
}

-(NSString *)getSpecialKeyString:(CFIndex)inKeyCode
{
	NSString *outKeyString = NULL;
	
	int specialKeyCount = sizeof(kSpecialKeys) / sizeof(KeyCodeAndName);
	int i;
	for(i = 0; i < specialKeyCount; i++)
	{
		if( kSpecialKeys[i].code == inKeyCode)
		{
			outKeyString = kSpecialKeys[i].name;
			break;
		}
	}

	if(outKeyString == NULL)
	{
		int specialGlyphCount = sizeof(kSpecialGlyph) / sizeof(KeyCodeAndGlyph);
		for(i = 0; i < specialGlyphCount; i++)
		{
			if( kSpecialGlyph[i].code == inKeyCode)
			{
				outKeyString = [NSString stringWithCharacters: &(kSpecialGlyph[i].glyph) length:1];
				break;
			}
		}
	}

	return outKeyString;
}

- (void)keyDown:(NSEvent *)theEvent
{
	keyCode = (CFIndex)[theEvent keyCode];
	modifiers = [theEvent modifierFlags];
    
	self.keyString = [self getSpecialKeyString:keyCode];

	if(self.keyString == nil)
        self.keyString = [theEvent charactersIgnoringModifiers];

	if(self.keyString == nil)
        self.keyString = @"";

	[self displayShortcut:self.keyString];
//	printf("\nkeyDown called. keycode=%d, modifier=%d\n", keyCode, modifiers);
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	keyCode = (CFIndex)[theEvent keyCode];
	modifiers = [theEvent modifierFlags];

    self.keyString = [self getSpecialKeyString:keyCode];

	if(self.keyString == NULL)
        self.keyString = [theEvent charactersIgnoringModifiers];

	if(self.keyString == NULL)
        self.keyString = @"";

	[self displayShortcut:self.keyString];

//	printf("\nperformKeyEquivalent called.keycode=%d, modifier=%d\n", keyCode, modifiers);
}

- (void)displayShortcut:(NSString*)theKey
{
	NSMutableString *displayString = [NSMutableString string];
	NSMutableString *shortString = [NSMutableString string];
	
    if((modifiers & NSControlKeyMask) != 0)
	{
		[displayString appendString:@"Control+"];
		[shortString appendString: [NSString stringWithCharacters: &kControlGlyph length:1]];
	}

    if((modifiers & NSAlternateKeyMask) != 0)
	{
		[displayString appendString:@"Option+"];
		[shortString appendString: [NSString stringWithCharacters: &kOptionGlyph length:1]];
	}

    if((modifiers & NSShiftKeyMask) != 0)
	{
		[displayString appendString:@"Shift+"];
		[shortString appendString: [NSString stringWithCharacters: &kShiftGlyph length:1]];
	}
	
    if((modifiers & NSCommandKeyMask) != 0)
	{
		[displayString appendString:@"Command+"];
		[shortString appendString: [NSString stringWithCharacters: &kCmdGlyph length:1]];
	}
	
	/*
    if((modifiers & NSAlphaShiftKeyMask) != 0)
	{
		[displayString appendString:@"Caps+"];
	}
	*/
	
	NSString *upperKey = nil;
	if([theKey length] == 1)
		upperKey = [theKey uppercaseString];
	else
		upperKey = theKey;

	[displayString appendString: upperKey];
	[shortString appendString: upperKey];
	
	if(mShortcutDisplay != NULL)
		[mShortcutDisplay setStringValue: displayString];
	
	if(mGlyphDisplay != NULL)
		[mGlyphDisplay setStringValue: shortString];
	
	if(mConflictDisplay == NULL)
		return;
	
	[mConflictDisplay setStringValue: @""];
	
	CFIndex carbonModifiers = [self getCarbonModifiers];

	Boolean hasSystemConflict = HasSystemHotKeyConflictForHotKey(mSystemHotKeyArray, carbonModifiers, keyCode);
	if(hasSystemConflict)
	{
		[mConflictDisplay setStringValue: NSLocalizedString(@"System_Conflict",@"")];
		return;
	}

	Boolean hasServicesConflict = HasServicesHotKeyConflictForHotKey(mServicesHotKeyArray, carbonModifiers, (__bridge CFStringRef)upperKey);

	if(hasServicesConflict)
	{
		[mConflictDisplay setStringValue: NSLocalizedString(@"Services_Conflict",@"")];
		return;
	}

	Boolean hasConflict = false;
	if( (mShortcutList != NULL) && (mPluginName != NULL) && (mSubmenuPath != NULL) && (mItemName != NULL) )
	{
		hasConflict	= HasConflictForHotKey(mShortcutList,
										carbonModifiers,
										keyCode,
										mPluginName,
										mSubmenuPath,
										mItemName );

		if(hasConflict)
			[mConflictDisplay setStringValue: NSLocalizedString(@"Shortcuts_Conflict",@"") ];
	}
}

- (void)setShortcutList: (CFArrayRef)inList pluginName: (CFStringRef)inPluginName submenuPath: (CFStringRef)inPath menuName: (CFStringRef)inName
{
	if( mShortcutList != NULL )
		CFRelease( mShortcutList );
	mShortcutList = inList;
	if(mShortcutList != NULL)
		CFRetain(mShortcutList);

	if( mPluginName != NULL )
		CFRelease( mPluginName );
	mPluginName = inPluginName;
	if(mPluginName != NULL)
		CFRetain(mPluginName);

	if( mSubmenuPath != NULL )
		CFRelease( mSubmenuPath );
	mSubmenuPath = inPath;
	if( mSubmenuPath != NULL )
		CFRetain( mSubmenuPath );

	if( mItemName != NULL )
		CFRelease( mItemName );
	mItemName = inName;
	if( mItemName != NULL )
		CFRetain( mItemName );

	if(mSystemHotKeyArray != NULL)
	{
		CFRelease(mSystemHotKeyArray);
		mSystemHotKeyArray = NULL;
	}

	OSStatus err = CopySymbolicHotKeys( &mSystemHotKeyArray );

	if(mServicesHotKeyArray != NULL)
	{
		CFRelease(mServicesHotKeyArray);
		mServicesHotKeyArray = NULL;
	}
}

Boolean
HasSystemHotKeyConflictForHotKey(CFArrayRef systemHotKeyArray, CFIndex inCarbonModifiers, CFIndex inKeyCode)
{
	if( systemHotKeyArray == NULL )
		return FALSE;

	CFIndex theCount = CFArrayGetCount(systemHotKeyArray);
	CFTypeID dictType = CFDictionaryGetTypeID();
	CFTypeID numType = CFNumberGetTypeID();
	CFTypeID boolType = CFBooleanGetTypeID();
	CFIndex i;
	for( i = 0; i < theCount; i++ )
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(systemHotKeyArray, i);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == dictType) )
		{
			CFDictionaryRef theDict = (CFDictionaryRef)theItem;
			CFTypeRef theResult = CFDictionaryGetValue( theDict, kHISymbolicHotKeyEnabled );
			Boolean enabled = true;
			if( (theResult != NULL) && (CFGetTypeID(theResult) == boolType) )
				enabled = CFBooleanGetValue( (CFBooleanRef)theResult );
			
			if(enabled)
			{
				CFIndex keyCode = 0;
				CFIndex keyModifiers = 0;
				
				theResult = CFDictionaryGetValue( theDict, kHISymbolicHotKeyCode );
				if( (theResult != NULL) && (CFGetTypeID(theResult) == numType) )
					CFNumberGetValue( (CFNumberRef)theResult, kCFNumberCFIndexType, &keyCode);
				
				theResult = CFDictionaryGetValue( theDict, kHISymbolicHotKeyModifiers );
				if( (theResult != NULL) && (CFGetTypeID(theResult) == numType) )
					CFNumberGetValue( (CFNumberRef)theResult, kCFNumberCFIndexType, &keyModifiers);
			
				if( (inKeyCode == keyCode) && (inCarbonModifiers == keyModifiers) )
				{
					return TRUE;
				}
			}
		}
	}
	return FALSE;
}

Boolean
HasServicesHotKeyConflictForHotKey(CFArrayRef servicesHotKeyArray, CFIndex inCarbonModifiers, CFStringRef inKeyString)
{
	if( (servicesHotKeyArray == NULL) || (inKeyString == NULL) )
		return FALSE;

	CFShow(servicesHotKeyArray);
	
	CFIndex inMenuModifiers = kMenuNoCommandModifier;
    if( (inCarbonModifiers & cmdKey) != 0 )
		inMenuModifiers &= ~kMenuNoCommandModifier;//clear the "no command" modifier

    if( (inCarbonModifiers & shiftKey) != 0 )
		inMenuModifiers |= kMenuShiftModifier;	

//    if((inCarbonModifiers & alphaLock) != 0)
//		inMenuModifiers |= ; <-- no equivalent

    if((inCarbonModifiers & optionKey) != 0)
		inMenuModifiers |= kMenuOptionModifier;

    if((inCarbonModifiers & controlKey) != 0)
		inMenuModifiers |= kMenuControlModifier;

	CFIndex theCount = CFArrayGetCount(servicesHotKeyArray);
	CFTypeID dictType = CFDictionaryGetTypeID();
	CFTypeID numType = CFNumberGetTypeID();
	CFTypeID stringType = CFStringGetTypeID();
	CFIndex i;
	for( i = 0; i < theCount; i++ )
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(servicesHotKeyArray, i);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == dictType) )
		{
			CFDictionaryRef theDict = (CFDictionaryRef)theItem;

			CFIndex menuModifiers = kMenuNoCommandModifier;

			CFTypeRef theResult = CFDictionaryGetValue( theDict, kHIServicesMenuKeyModifiers );
			if( (theResult != NULL) && (CFGetTypeID(theResult) == numType) )
				CFNumberGetValue( (CFNumberRef)theResult, kCFNumberCFIndexType, &menuModifiers);
			
			if(menuModifiers == inMenuModifiers)
			{
				theResult = CFDictionaryGetValue( theDict, kHIServicesMenuCharCode );
				if( (theResult != NULL) && (CFGetTypeID(theResult) == stringType) )
				{
					if( CFStringCompare(inKeyString, (CFStringRef)theResult, kCFCompareCaseInsensitive) == kCFCompareEqualTo )
						return TRUE;
				}
			}	
		}
	}
	return FALSE;
}

@end
