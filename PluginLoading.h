/*
 *  PluginLoading.h
 *  Shortcuts
 *
 *  Created by Tom on 2/20/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

#ifdef __cplusplus
extern "C" {
#endif


typedef struct LoadedPlugin
{
	CFURLRef pluginURL;//we own it, retained
	ContextualMenuInterfaceStruct **interface;//owned but never released, we keep it till we die
	struct LoadedPlugin *prevPlugin;
} LoadedPlugin;

ContextualMenuInterfaceStruct **	LoadPlugin(CFURLRef inPluginURLRef);
ContextualMenuInterfaceStruct **	FindLoadedPlugin(const LoadedPlugin* inLoadedPluginChain, CFURLRef inPluginURLRef);
LoadedPlugin*						AddLoadedPluginToChain(LoadedPlugin* inLoadedPluginChain, CFURLRef inPluginURLRef, ContextualMenuInterfaceStruct **inInterface);
void								ReleaseLoadedPluginChain(LoadedPlugin* inLoadedPluginChain);


#ifdef __cplusplus
}
#endif


