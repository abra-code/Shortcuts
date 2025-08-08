/*
 *  ExtractCMItemData.cpp
 *  Shortcuts
 *
 *  Created by Tom on 2/18/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include "ExtractCMItemData.h"
#include "AEDescText.h"

//all pointers passed to this function must be non-null
//ioSubmenuList must be the empty AEDesc preallocated before calling this function
//caller responsible for releasing outMenuItemName and ioSubmenuList

const AEDesc kNullDesc = {typeNull, NULL};


OSStatus
ExtractCMItemData(
					const AERecord *inMenuItemRec,
					CFStringRef *outMenuItemName, SInt32 *outCommandID, UInt32 *outAttribs, UInt32 *outModifiers,
					Boolean *outIsSubmenu, AEDescList *ioSubmenuList )
{

	*outMenuItemName = NULL;
	*outCommandID = 0;
	*outIsSubmenu = false;
	*ioSubmenuList = kNullDesc;
	*outAttribs = 0;
	*outModifiers = kMenuNoModifiers;

	if(inMenuItemRec == NULL)
		return paramErr;
	
	long recItemsCount = 0;
	OSStatus err = AECountItems(inMenuItemRec, &recItemsCount);
	if( (err == noErr) && (recItemsCount > 0) )
	{
		AEDesc oneItem;
		SInt32 i;
		for(i = 1; i <= recItemsCount; i++)
		{
			Boolean releaseItem = true;
			AEKeyword theKeyword;
			err = AEGetNthDesc(inMenuItemRec, i, typeWildCard, &theKeyword, &oneItem);
			if(err == noErr)
			{
				switch(theKeyword)
				{
					case keyContextualMenuName:
					{
						*outMenuItemName = CreateCFStringFromAEDesc(&oneItem);
						//if(*outMenuItemName != NULL)
						//	retainCount = CFGetRetainCount(*outMenuItemName);

					}
					break;
				
					case keyContextualMenuCommandID:
					{
						err = AEGetDescData( &oneItem, outCommandID, sizeof(SInt32) );
					}
					break;
					
					case keyContextualMenuSubmenu:
					{
						*outIsSubmenu = true;
						releaseItem = false;
						*ioSubmenuList = oneItem;//do not release the AEDesc when it is submenu - we return this value
					}
					break;
					
					case keyContextualMenuAttributes:
					{
						err = AEGetDescData( &oneItem, outAttribs, sizeof(UInt32) );
					}
					break;
					
					case keyContextualMenuModifiers:
					{
						err = AEGetDescData( &oneItem, outModifiers, sizeof(UInt32) );
					}
					break;

					default:
					break;
				}
				
				if(releaseItem)
				{
					AEDisposeDesc(&oneItem);
					//AEDisposeDesc does not release the CFString in it so we are safe here
					
					/*
					if(*outMenuItemName != NULL)
					{
						CFIndex retainCount = CFGetRetainCount(*outMenuItemName);
						printf("retain count is: %d", retainCount);
					}
					*/
				}
			}
		}
	}
	return err;
}


