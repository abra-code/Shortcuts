/*
 *  ExtractCMItemData.h
 *  Shortcuts
 *
 *  Created by Tom on 2/18/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

#ifdef __cplusplus
extern "C" {
#endif

OSStatus ExtractCMItemData(
						const AERecord *inMenuItemRec,
						CFStringRef *outMenuItemName, SInt32 *outCommandID, UInt32 *outAttribs, UInt32 *outModifiers,
						Boolean *outIsSubmenu, AEDescList *ioSubmenuList );

#ifdef __cplusplus
}
#endif

