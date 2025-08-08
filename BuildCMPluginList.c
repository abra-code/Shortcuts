/*
 *  BuildCMPluginList.cpp
 *  Shortcuts
 *
 *  Created by Tom on 2/18/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include "BuildCMPluginList.h"
#include <Carbon/Carbon.h>

typedef enum FolderItemsMatchOptions
{
	kFolderItemsMatch_NoOptions = 0,
	kFolderItemsMatch_FilesOnly,
	kFolderItemsMatch_FoldersOnly
} FolderItemsMatchOptions;

//returns array of CFURLRefs
CFArrayRef
CreateItemURLArrayForDirectory(FSRef *folderRef, FolderItemsMatchOptions inOptions, CFStringRef inExtensionToMatch)
{
	enum
	{
		kMaxItemsPerBulkCall = 10 //Grab items 10 at a time
	};
	
	OSErr		result;
	FSIterator	iterator;
	FSRef		refs[kMaxItemsPerBulkCall];
	FSCatalogInfo catInfos[kMaxItemsPerBulkCall];
	ItemCount	actualObjects;
	CFURLRef	oneURL;
	int i;
	Boolean		changed = false;

	CFMutableArrayRef outArray = CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );
	if(outArray == NULL)
		return NULL;

	/* open an FSIterator */
	result = FSOpenIterator(folderRef, kFSIterateFlat, &iterator);
	if(result != noErr)
	{
		CFRelease(outArray);
		return NULL;
	}

	FSCatalogInfoBitmap catInfoBitmap = kFSCatInfoNone;
	if( (inOptions == kFolderItemsMatch_FilesOnly) || (inOptions == kFolderItemsMatch_FoldersOnly) )
	{
		catInfoBitmap |= kFSCatInfoNodeFlags;
	}

	// Call FSGetCatalogInfoBulk in loop to get all items in the container
	do
	{
		result = FSGetCatalogInfoBulk(iterator, kMaxItemsPerBulkCall, &actualObjects,
					&changed, catInfoBitmap, catInfos,  refs, NULL, NULL);
	
		//any result other than noErr and errFSNoMoreItems is serious
		if( (noErr == result) || (errFSNoMoreItems == result) )
		{
			for(i = 0; i < actualObjects; i++)
			{
				Boolean addItem = true;
				if(inOptions == kFolderItemsMatch_FilesOnly)
					addItem = ((catInfos[i].nodeFlags & kFSNodeIsDirectoryMask) == 0);
				else if(inOptions == kFolderItemsMatch_FoldersOnly)
					addItem = ((catInfos[i].nodeFlags & kFSNodeIsDirectoryMask) != 0);
				
				if(addItem)
				{
					oneURL = CFURLCreateFromFSRef( kCFAllocatorSystemDefault, &refs[i] );
					if(oneURL != NULL)
					{
						if(inExtensionToMatch != NULL)
						{
							addItem = false;
							CFStringRef ext = CFURLCopyPathExtension(oneURL);
							if(ext != NULL)
								addItem = (kCFCompareEqualTo == CFStringCompare(inExtensionToMatch, ext, kCFCompareCaseInsensitive));
						}

						if(addItem)
							CFArrayAppendValue(outArray, oneURL);
						CFRelease(oneURL);
					}
				}
			}
		}
	}
	while( noErr == result );

	result = FSCloseIterator(iterator);
	
	return outArray;
}

Boolean
IsPluginLoadable(CFURLRef inPluginURL)
{
#if defined(__arm64__)
    CFIndex myArchitecture = kCFBundleExecutableArchitectureARM64;
#elif defined(__x86_64__)
	CFIndex myArchitecture = kCFBundleExecutableArchitectureX86_64;
#else
    #error Unsupported architecture
#endif
    
	Boolean isLoadable = false;
	CFBundleRef pluginBundle = CFBundleCreate( kCFAllocatorDefault, inPluginURL );
	if(pluginBundle != NULL)
	{
		CFArrayRef availableArchitectures = CFBundleCopyExecutableArchitectures( pluginBundle );
		if(availableArchitectures != NULL)
		{
			CFIndex theCount = CFArrayGetCount(availableArchitectures);
			for(CFIndex i = 0; i < theCount; i++)
			{
				CFNumberRef oneArchNum = (CFNumberRef)CFArrayGetValueAtIndex(availableArchitectures, i);
				if(oneArchNum != NULL)
				{
					CFIndex oneArchValue = 0;//invalid arch
					if( CFNumberGetValue(oneArchNum, kCFNumberCFIndexType, &oneArchValue) )
					{	
						if(myArchitecture == oneArchValue)
						{
							isLoadable = true;
							break;
						}
					}
				}
			}
			CFRelease(availableArchitectures);
		}
	}
	return isLoadable;
}

//returns array of CFURLRefs
CFMutableArrayRef
BuildCMPluginList(void)
{
	OSErr err;
	FSRef folderRef;
	CFIndex i;
	CFStringRef pluginExt = CFSTR("plugin");

	CFMutableArrayRef outArray = CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );
	if(outArray == NULL)
		return NULL;

//user plugins	
	memset(&folderRef, 0, sizeof(folderRef));
	err = FSFindFolder(kUserDomain, kContextualMenuItemsFolderType, false, &folderRef);
	if(err == noErr)
	{
		CFArrayRef oneLocationItems = CreateItemURLArrayForDirectory(&folderRef, kFolderItemsMatch_FoldersOnly, pluginExt);
		if(oneLocationItems != NULL)
		{
			CFIndex itemCount = CFArrayGetCount(oneLocationItems);
			for( i = 0; i < itemCount; i++ )
			{
				CFURLRef oneURL = CFArrayGetValueAtIndex(oneLocationItems, i);
				Boolean isLoadable = IsPluginLoadable(oneURL);
				if( isLoadable )
					CFArrayAppendValue(outArray, oneURL);
			}
			CFRelease(oneLocationItems);
		}
	}

//global plugins	
	memset(&folderRef, 0, sizeof(folderRef));
	err = FSFindFolder(kLocalDomain, kContextualMenuItemsFolderType, false, &folderRef);
	if(err == noErr)
	{
		CFArrayRef oneLocationItems = CreateItemURLArrayForDirectory(&folderRef, kFolderItemsMatch_FoldersOnly, pluginExt);
		if(oneLocationItems != NULL)
		{
			CFIndex itemCount = CFArrayGetCount(oneLocationItems);
			for( i = 0; i < itemCount; i++ )
			{
				CFURLRef oneURL = CFArrayGetValueAtIndex(oneLocationItems, i);
				Boolean isLoadable = IsPluginLoadable(oneURL);
				if( isLoadable )
					CFArrayAppendValue(outArray, oneURL);
			}
			CFRelease(oneLocationItems);
		}
	}

	return outArray;
}

