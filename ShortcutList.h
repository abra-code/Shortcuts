/*
 *  ShortcutList.h
 *  ShortcutObserver
 *
 *  Created by Tom on 2/25/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

CFMutableArrayRef CreateShortcutList(void);

void AddShortcut(
			CFMutableArrayRef ioList,
			CFStringRef inPluginName,
			CFStringRef inSubmenuPath,
			CFStringRef inMenuItemName,
			CFStringRef inKeyChar,
			CFIndex inCarbonModifiers,
			CFIndex inKeyCode,
			Boolean pefersTextContext);

CFIndex FindShortcut(
			CFArrayRef inShortcutList,
			CFStringRef inPluginName,
			CFStringRef inSubmenuPath,
			CFStringRef inMenuItemName,
			CFStringRef *outKeyChar,
			CFIndex *outModifiers,
			CFIndex *outKeyCode);

Boolean HasConflictForHotKey(CFArrayRef inShortcutList,
					CFIndex inModifiers,
					CFIndex inKeyCode,
					CFStringRef inPluginName,
					CFStringRef inSubmenuPath,
					CFStringRef inMenuItemName );

void CopyShortcutKeyAndModifiers(
			CFDictionaryRef theDict,
			CFStringRef *outKeyChar,
			CFIndex *outModifiers,
			CFIndex *outKeyCode);

CFDictionaryRef CreateShortcutKeyAndModifiersDictionary(
			CFStringRef inKeyChar,
			CFIndex inModifiers,
			CFIndex inKeyCode);

void FetchShortcutKeyAndModifiers(
			CFArrayRef inShortcutList,
			CFIndex inIndex,
			CFStringRef *outKeyChar,
			CFIndex *outModifiers,
			CFIndex *outKeyCode);

void
FetchShortcutMenuItemData(
			CFArrayRef inShortcutList,
			CFIndex inIndex,
			CFStringRef *outPluginName,
			CFStringRef *outSubmenuPath,
			CFStringRef *outMenuItemName,
			Boolean *outPefersTextContext);

CFMutableArrayRef LoadMutableShortcutListFromPrefs(
					CFStringRef inPrefsIdentifier,
					CFStringRef inKey);

CFArrayRef LoadShortcutsFromPrefs(
				CFStringRef inPrefsIdentifier,
				CFStringRef inKey);

void SaveShortcutsToPrefs(
		CFStringRef inPrefsIdentifier,
		CFStringRef inKey,
		CFArrayRef inList);

#ifdef __cplusplus
}
#endif


