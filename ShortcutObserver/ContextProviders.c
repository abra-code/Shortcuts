/*
 *  ContextProviders.c
 *  ShortcutObserver
 *
 *  Created by Tom on 3/3/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include "ContextProviders.h"

ContextScriptInfo*
AddScriptToChain( ContextScriptInfo* inChain, CFStringRef inName, const FSRef *inFileRef )
{
	ContextScriptInfo *newHead = malloc(sizeof(ContextScriptInfo));
	newHead->name = inName;
	newHead->fileRef = *inFileRef;
	newHead->scriptRef = kOSANullScript;//initially do not do not load the script, only when needed
	newHead->prevScript = inChain;//attach the tail
	return newHead;//now the new item is the head
}

void
ReleaseScriptChain(ComponentInstance inOSAComponent, ContextScriptInfo* inChain)
{
	ContextScriptInfo* currItem = inChain;
	ContextScriptInfo* tempItem;
	while(currItem != NULL)
	{
		if(currItem->name != NULL)
			CFRelease(currItem->name);

		if(currItem->scriptRef != kOSANullScript)
			OSADispose( inOSAComponent, currItem->scriptRef );

		tempItem = currItem;
		currItem = currItem->prevScript;
		free(tempItem);
	}
}

ContextScriptInfo*
FindScriptByName(ContextScriptInfo* inChain, CFStringRef inName)
{
	ContextScriptInfo* currItem = inChain;
	while(currItem != NULL)
	{
		if(currItem->name != NULL)
			if( kCFCompareEqualTo == CFStringCompare(inName, currItem->name, 0) )
				return currItem;
				
		currItem = currItem->prevScript;
	}
	return NULL;
}
