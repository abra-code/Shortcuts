/*
 *  ShortcutList.c
 *  ShortcutObserver
 *
 *  Created by Tom on 2/25/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include "ShortcutList.h"

CFMutableArrayRef
CreateShortcutList(void)
{
	return CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );
}

void
AddShortcut(CFMutableArrayRef ioList,
			CFStringRef inPluginName,
			CFStringRef inSubmenuPath,
			CFStringRef inMenuItemName,
			CFStringRef inKeyChar,
			CFIndex inCarbonModifiers,//only 16 bits unsigned used so safe to cast into signed 32 bit CFIndex
			CFIndex inKeyCode, //same here
			Boolean pefersTextContext
			)
{
	CFMutableDictionaryRef theDict = CFDictionaryCreateMutable(
						kCFAllocatorDefault,
						0,
						&kCFTypeDictionaryKeyCallBacks,
						&kCFTypeDictionaryValueCallBacks);
	if(theDict!= NULL)
	{
		CFDictionarySetValue(theDict, CFSTR("PLUGIN"), inPluginName);
		CFDictionarySetValue(theDict, CFSTR("SUBMENU"), inSubmenuPath);//retained
		CFDictionarySetValue(theDict, CFSTR("NAME"), inMenuItemName);
		CFDictionarySetValue(theDict, CFSTR("KEYCHAR"), inKeyChar);
		CFNumberRef oneNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &inCarbonModifiers);
		CFDictionarySetValue(theDict, CFSTR("MODIFIERS"), oneNumber);//retained
		CFRelease(oneNumber);
		oneNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &inKeyCode);
		CFDictionarySetValue(theDict, CFSTR("KEYCODE"), oneNumber);//retained
		CFRelease(oneNumber);
		CFDictionarySetValue(theDict, CFSTR("PREFERS_TEXT_CONTEXT"), pefersTextContext ? kCFBooleanTrue : kCFBooleanFalse);//retained
		CFArrayAppendValue( ioList, (const void *)theDict );//retained
		CFRelease(theDict);
	}
}

//positive result = found
//negative = not found
//caller responsible for releasing non-null *outKeyChar
CFIndex
FindShortcut(CFArrayRef inShortcutList,
			CFStringRef inPluginName,
			CFStringRef inSubmenuPath,
			CFStringRef inMenuItemName,
			CFStringRef *outKeyChar,
			CFIndex *outModifiers,
			CFIndex *outKeyCode)
{
	CFIndex foundIndex = -1;
	CFIndex	theCount = CFArrayGetCount(inShortcutList);
	CFIndex i;
	for(i = 0; i < theCount; i++)
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(inShortcutList, i);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == CFDictionaryGetTypeID()) )
		{
			CFDictionaryRef theDict = (CFDictionaryRef)theItem;
			//we are betting on the fact that the name is most likely to be unique so use it as a first criteria
			CFTypeRef theResult = CFDictionaryGetValue( theDict, CFSTR("NAME") );
			if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
				if( kCFCompareEqualTo == CFStringCompare(inMenuItemName, (CFStringRef)theResult, 0) )
				{//name equal, now check plugin name and submenu path
					theResult = CFDictionaryGetValue( theDict, CFSTR("PLUGIN") );
					if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
						if( kCFCompareEqualTo == CFStringCompare(inPluginName, (CFStringRef)theResult, 0) )
						{
							theResult = CFDictionaryGetValue( theDict, CFSTR("SUBMENU") );
							if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
								if( kCFCompareEqualTo == CFStringCompare(inSubmenuPath, (CFStringRef)theResult, 0) )
								{
									if(outKeyChar != NULL)
									{
										*outKeyChar = NULL;
										theResult = CFDictionaryGetValue( theDict, CFSTR("KEYCHAR") );
										if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
										{
											CFRetain(theResult);
											*outKeyChar = (CFStringRef)theResult;
										}
									}
									
									if(outModifiers != NULL)
									{
										*outModifiers = 0;
										theResult = CFDictionaryGetValue( theDict, CFSTR("MODIFIERS") );
										if((theResult != NULL) && (CFNumberGetTypeID() == CFGetTypeID(theResult)) )
											CFNumberGetValue((CFNumberRef)theResult, kCFNumberCFIndexType, outModifiers);
									}
									
									if(outKeyCode != NULL)
									{
										*outKeyCode = 0;
										theResult = CFDictionaryGetValue( theDict, CFSTR("KEYCODE") );
										if((theResult != NULL) && (CFNumberGetTypeID() == CFGetTypeID(theResult)) )
											CFNumberGetValue((CFNumberRef)theResult, kCFNumberCFIndexType, outKeyCode);
									}

									foundIndex = i;
									break;
								}
						}
				}
		}
	}
	return foundIndex;
}

//search the list for modifiers and key code
//if a match is found, use item name, submenu path and plugin name to see "who's asking"
//if the hot key is found for some other item it is a conflict. for our item it is not

Boolean
HasConflictForHotKey(CFArrayRef inShortcutList,
					CFIndex inModifiers,
					CFIndex inKeyCode,
					CFStringRef inPluginName,
					CFStringRef inSubmenuPath,
					CFStringRef inMenuItemName )
{
	CFIndex	theCount = CFArrayGetCount(inShortcutList);
	CFIndex i;
	Boolean hasConflict = false;
	CFNumberRef modifiers = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &inModifiers);
	CFNumberRef keyCode = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &inKeyCode);

	for(i = 0; i < theCount; i++)
	{
		CFTypeRef theItem = CFArrayGetValueAtIndex(inShortcutList, i);
		if( (theItem != NULL) && (CFGetTypeID(theItem) == CFDictionaryGetTypeID()) )
		{
			CFDictionaryRef theDict = (CFDictionaryRef)theItem;
			Boolean foundMatch = false;
			
			CFTypeRef theResult = CFDictionaryGetValue( theDict, CFSTR("KEYCODE") );
			if( theResult != NULL )
				foundMatch = CFEqual( (CFNumberRef)theResult, keyCode );

			if(foundMatch)
			{
				foundMatch = false;
				theResult = CFDictionaryGetValue( theDict, CFSTR("MODIFIERS") );
				if( theResult != NULL )
					foundMatch = CFEqual( (CFNumberRef)theResult, modifiers );
				
				if( foundMatch ) //a true match is found, check who's asking
				{
					Boolean isEqual = false;
					theResult = CFDictionaryGetValue( theDict, CFSTR("NAME") );
					if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
						isEqual = ( kCFCompareEqualTo == CFStringCompare(inMenuItemName, (CFStringRef)theResult, 0) );
					
					if(!isEqual)
					{
						hasConflict = true;
						break;
					}
					
					isEqual = false;
					theResult = CFDictionaryGetValue( theDict, CFSTR("PLUGIN") );
					if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
						isEqual = ( kCFCompareEqualTo == CFStringCompare(inPluginName, (CFStringRef)theResult, 0) );
					
					if(!isEqual)
					{
						hasConflict = true;
						break;
					}
					
					isEqual = false;
					theResult = CFDictionaryGetValue( theDict, CFSTR("SUBMENU") );
					if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
						isEqual = ( kCFCompareEqualTo == CFStringCompare(inSubmenuPath, (CFStringRef)theResult, 0) );
					
					if(!isEqual)
					{
						hasConflict = true;
						break;
					}
					
				}
			}
		}
	}

	CFRelease(modifiers);
	CFRelease(keyCode);

	return hasConflict;
}

//caller responsible for releasing string put in outKeyChar
void
CopyShortcutKeyAndModifiers(CFDictionaryRef theDict,
							CFStringRef *outKeyChar, CFIndex *outModifiers, CFIndex *outKeyCode)
{
	CFTypeRef theResult;

	if(outKeyChar != NULL)
	{
		*outKeyChar = NULL;
		theResult = CFDictionaryGetValue( theDict, CFSTR("KEYCHAR") );
		if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
		{
			CFRetain(theResult);
			*outKeyChar = (CFStringRef)theResult;
		}
	}

	if(outModifiers != NULL)
	{
		*outModifiers = 0;
		theResult = CFDictionaryGetValue( theDict, CFSTR("MODIFIERS") );
		if((theResult != NULL) && (CFNumberGetTypeID() == CFGetTypeID(theResult)) )
			CFNumberGetValue((CFNumberRef)theResult, kCFNumberCFIndexType, outModifiers);
	}
	
	if(outKeyCode != NULL)
	{
		*outKeyCode = 0;
		theResult = CFDictionaryGetValue( theDict, CFSTR("KEYCODE") );
		if((theResult != NULL) && (CFNumberGetTypeID() == CFGetTypeID(theResult)) )
			CFNumberGetValue((CFNumberRef)theResult, kCFNumberCFIndexType, outKeyCode);
	}
}

CFDictionaryRef
CreateShortcutKeyAndModifiersDictionary(CFStringRef inKeyChar, CFIndex inModifiers, CFIndex inKeyCode)
{
	CFMutableDictionaryRef theDict = CFDictionaryCreateMutable(
						kCFAllocatorDefault,
						0,
						&kCFTypeDictionaryKeyCallBacks,
						&kCFTypeDictionaryValueCallBacks);
	if(theDict!= NULL)
	{
		CFDictionarySetValue(theDict, CFSTR("KEYCHAR"), inKeyChar);
		CFNumberRef oneNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &inModifiers);
		CFDictionarySetValue(theDict, CFSTR("MODIFIERS"), oneNumber);//retained
		CFRelease(oneNumber);
		oneNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &inKeyCode);
		CFDictionarySetValue(theDict, CFSTR("KEYCODE"), oneNumber);//retained
		CFRelease(oneNumber);
	}
	return theDict;
}

//quick fetch, no array bounds check
//caller responsible for releasing non-null *outKeyChar
void
FetchShortcutKeyAndModifiers(CFArrayRef inShortcutList, CFIndex inIndex,
							CFStringRef *outKeyChar, CFIndex *outModifiers, CFIndex *outKeyCode)
{
	CFTypeRef theItem = CFArrayGetValueAtIndex(inShortcutList, inIndex);
	if( (theItem != NULL) && (CFGetTypeID(theItem) == CFDictionaryGetTypeID()) )
	{
		CopyShortcutKeyAndModifiers((CFDictionaryRef)theItem, outKeyChar, outModifiers, outKeyCode);
	}
	else
	{
		if(outKeyChar != NULL)
			*outKeyChar = NULL;

		if(outModifiers != NULL)
			*outModifiers = 0;

		if(outKeyCode != NULL)
			*outKeyCode = 0;
	}
}


//retain result strings if you plan to keep them
//valid CFStringRef pointers are expected and required
void
FetchShortcutMenuItemData(
			CFArrayRef inShortcutList,
			CFIndex inIndex,
			CFStringRef *outPluginName,
			CFStringRef *outSubmenuPath,
			CFStringRef *outMenuItemName,
			Boolean *outPefersTextContext)
{
	CFTypeRef theItem = CFArrayGetValueAtIndex(inShortcutList, inIndex);
	if( (theItem != NULL) && (CFGetTypeID(theItem) == CFDictionaryGetTypeID()) )
	{
		CFDictionaryRef theDict = (CFDictionaryRef)theItem;

		CFTypeRef theResult = CFDictionaryGetValue( theDict, CFSTR("PLUGIN") );
		if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
			*outPluginName = (CFStringRef)theResult;

		theResult = CFDictionaryGetValue( theDict, CFSTR("SUBMENU") );
		if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
			*outSubmenuPath = (CFStringRef)theResult;

		theResult = CFDictionaryGetValue( theDict, CFSTR("NAME") );
		if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
			*outMenuItemName = (CFStringRef)theResult;
	
		theResult = CFDictionaryGetValue( theDict, CFSTR("PREFERS_TEXT_CONTEXT") );
		if((theResult != NULL) && (CFBooleanGetTypeID() == CFGetTypeID(theResult)) )
			*outPefersTextContext = CFBooleanGetValue(theResult);
	}
}



//you may need to call CFPreferencesAppSynchronize before calling this function
//caller responsible for releasing result array
CFMutableArrayRef
LoadMutableShortcutListFromPrefs(CFStringRef inPrefsIdentifier, CFStringRef inKey)
{
	CFMutableArrayRef outList = NULL;

	if( (inPrefsIdentifier == NULL) || (inKey == NULL) )
		return CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );

	CFPropertyListRef resultRef = CFPreferencesCopyAppValue( inKey, inPrefsIdentifier );
	if(resultRef != NULL)
	{
		if( CFGetTypeID(resultRef) == CFArrayGetTypeID() )
		{//we need a mutable copy of this array
			outList = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, (CFArrayRef)resultRef);
			CFRelease(resultRef);
		}
	}
	
	if(outList == NULL)
		outList = CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );

	return outList;
}

//you may need to call CFPreferencesAppSynchronize before calling this function
//caller responsible for releasing result array

CFArrayRef
LoadShortcutsFromPrefs(CFStringRef inPrefsIdentifier, CFStringRef inKey)
{
	CFArrayRef outList = NULL;

	if( (inPrefsIdentifier == NULL) || (inKey == NULL) )
		return CFArrayCreate(kCFAllocatorDefault, NULL, 0, &kCFTypeArrayCallBacks);

	CFPropertyListRef resultRef = CFPreferencesCopyAppValue( inKey, inPrefsIdentifier );
	if(resultRef != NULL)
	{
		if( CFGetTypeID(resultRef) == CFArrayGetTypeID() )
			outList = (CFArrayRef)resultRef;
	}
	
	if(outList == NULL)
		outList = CFArrayCreate(kCFAllocatorDefault, NULL, 0, &kCFTypeArrayCallBacks);
	
	return outList;
}


//you may need to call CFPreferencesAppSynchronize after calling this function
void
SaveShortcutsToPrefs(CFStringRef inPrefsIdentifier, CFStringRef inKey, CFArrayRef inList)
{
	if((inList != NULL) && (inKey != NULL) && (inPrefsIdentifier != NULL))
	 	CFPreferencesSetAppValue( inKey, (CFPropertyListRef)inList, inPrefsIdentifier );
}

