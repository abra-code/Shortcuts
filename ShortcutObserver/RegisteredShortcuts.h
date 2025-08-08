/*
 *  RegisteredShortcuts.h
 *  ShortcutObserver
 *
 *  Created by Tom on 3/3/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

#ifdef __cplusplus
extern "C" {
#endif


typedef struct RegisteredShortcut
{
	EventHotKeyRef hotKey;//don't release it, unregister it
	struct RegisteredShortcut *prevShortcut;
} RegisteredShortcut;

RegisteredShortcut* AddRegisteredShortcutToChain(RegisteredShortcut* inChain, EventHotKeyRef inHotKeyRef);
void ReleaseRegisteredShortcutChain(RegisteredShortcut* inChain);


#ifdef __cplusplus
}
#endif


