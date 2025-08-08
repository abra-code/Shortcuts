/*
 *  PluginLoading.c
 *  Shortcuts
 *
 *  Created by Tom on 2/20/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include "PluginLoading.h"
#include <CoreFoundation/CFPlugInCOM.h>

//load and return plugin interface
ContextualMenuInterfaceStruct **
LoadPlugin(CFURLRef inPluginURLRef)
{
	CFArrayRef factories = NULL;
	CFUUIDRef factoryID = NULL;
	IUnknownVTbl **iunknown = NULL;
	ContextualMenuInterfaceStruct **interface = NULL;

	// Create a CFPlugin using the URL.
	// This step causes the plug-in's types and factories to be
	// registered with the system.
	// Note that the plug-in's code is not loaded unless the plug-in
	// is using dynamic registration.

	CFPlugInRef plugin = CFPlugInCreate(kCFAllocatorDefault, inPluginURLRef);
	//never release this plugin, keep it for the lifetime of our app
	if(plugin == NULL)
	{
		printf("\nLoadPlugin: Failed to CFPlugInCreate.");
		return NULL;
	}
	
	// See if this plug-in implements the Test type.
	factories = CFPlugInFindFactoriesForPlugInTypeInPlugIn(kContextualMenuTypeID, plugin);
	if(factories == NULL)
	{
		printf("\nLoadPlugin: Failed to CFPlugInFindFactoriesForPlugInTypeInPlugIn.\n");
		return NULL;
	}

	if( CFArrayGetCount(factories) == 0 )
	{
		printf("\nLoadPlugin: CFPlugInFindFactoriesForPlugInTypeInPlugIn found 0 factories\n");
		CFRelease(factories);
		return NULL;
	}
	
	// attempt to get the IUnknown interface.
	// Get the factory ID for the first location in the array of IDs.
	factoryID = (CFUUIDRef)CFArrayGetValueAtIndex(factories, 0);

	if(factoryID == NULL)
	{
		printf("\nLoadPlugin: Failed. First factory is null\n");
		CFRelease(factories);
		return NULL;
	}

	// Use the factory ID to get an IUnknown interface.
	// Here the code for the PlugIn is loaded.
	iunknown = (IUnknownVTbl **)CFPlugInInstanceCreate(kCFAllocatorDefault, factoryID, kContextualMenuTypeID);

	CFRelease(factories);
	factoryID = NULL;

	if (iunknown == NULL)
	{
		printf("\nLoadPlugin: Failed to CFPlugInInstanceCreate.\n");
		return NULL;
	}

	// If this is an IUnknown interface, query for the CM plugin interface.
	(*iunknown)->QueryInterface(iunknown,
				CFUUIDGetUUIDBytes(kContextualMenuInterfaceID),
				(LPVOID *)(&interface));

	// Done with IUnknown.
	(*iunknown)->Release(iunknown);

	//indeed it is a CM plugin interface
	if(interface == NULL)
	{
		printf("\nLoadPlugin: Failed to find CM plugin interface.\n"); 
	}


	// This causes the plug-in's code to be unloaded.
	//never release the plugin becuase bundles with Obj-C code cannot be unloaded and will crash
	//(*interface)->Release(interface);

	// Memory for the plug-in is deallocated here.
	//never release the plugin becuase bundles with Obj-C code cannot be unloaded and will crash
	//CFRelease(plugin);

	return interface;
}

ContextualMenuInterfaceStruct **
FindLoadedPlugin(const LoadedPlugin* inLoadedPluginChain, CFURLRef inPluginURLRef)
{
	const LoadedPlugin*currPlug = inLoadedPluginChain;
	while(currPlug != NULL)
	{
		if( (currPlug->pluginURL != NULL) &&
			(currPlug->interface != NULL) &&
			CFEqual(currPlug->pluginURL, inPluginURLRef) )
		{
			return currPlug->interface;
		}
		currPlug = currPlug->prevPlugin;
	}
	return NULL;
}

LoadedPlugin*
AddLoadedPluginToChain(LoadedPlugin* inLoadedPluginChain, CFURLRef inPluginURLRef, ContextualMenuInterfaceStruct **inInterface)
{
	LoadedPlugin *newHead = malloc(sizeof(LoadedPlugin));
	newHead->pluginURL = inPluginURLRef;
	CFRetain(newHead->pluginURL);
	newHead->interface = inInterface;
	newHead->prevPlugin = inLoadedPluginChain;//attach the tail
	return newHead;//now the new plug is the head
}

void
ReleaseLoadedPluginChain(LoadedPlugin* inLoadedPluginChain)
{
	LoadedPlugin* currPlug = inLoadedPluginChain;
	LoadedPlugin* tempPlug;
	while(currPlug != NULL)
	{
		if(currPlug->pluginURL != NULL)
			CFRelease(currPlug->pluginURL);
		
		//never release the interface becuase we may crash: currPlug->interface
		tempPlug = currPlug;
		currPlug = currPlug->prevPlugin;
		free(tempPlug);
	}
}
