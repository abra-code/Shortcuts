/*
 *  RegisteredShortcuts.c
 *  ShortcutObserver
 *
 *  Created by Tom on 3/3/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include "RegisteredShortcuts.h"

RegisteredShortcut*
AddRegisteredShortcutToChain(RegisteredShortcut* inChain, EventHotKeyRef inHotKeyRef)
{
	RegisteredShortcut *newHead = malloc(sizeof(RegisteredShortcut));
	newHead->hotKey = inHotKeyRef;
	newHead->prevShortcut = inChain;//attach the tail
	return newHead;//now the new item is the head
}

void
ReleaseRegisteredShortcutChain(RegisteredShortcut* inChain)
{
	RegisteredShortcut* currItem = inChain;
	RegisteredShortcut* tempItem;
	while(currItem != NULL)
	{
		if(currItem->hotKey != NULL)
			UnregisterEventHotKey(currItem->hotKey);
		tempItem = currItem;
		currItem = currItem->prevShortcut;
		free(tempItem);
	}
}
