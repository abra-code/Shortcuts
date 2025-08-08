/*
 *  ContextProviders.h
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


typedef struct ContextScriptInfo
{
	CFStringRef name;//we own it, responsible for releasing
	FSRef fileRef;
	OSAID scriptRef;
	struct ContextScriptInfo *prevScript;
} ContextScriptInfo;

ContextScriptInfo* AddScriptToChain( ContextScriptInfo* inChain, CFStringRef inName, const FSRef *inFileRef );
void ReleaseScriptChain(ComponentInstance inOSAComponent, ContextScriptInfo* inChain);
ContextScriptInfo* FindScriptByName(ContextScriptInfo* inChain, CFStringRef inName);


#ifdef __cplusplus
}
#endif


