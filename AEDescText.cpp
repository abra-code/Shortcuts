/*
 *  AEDescText.c
 *  Shortcuts
 *
 *  Created by Tom on 5/28/05.
 *  Copyright 2005 Abracode_. All rights reserved.
 *
 */

#include "AEDescText.h"


OSStatus
CreateUniTextDescFromCFString(CFStringRef inStringRef, AEDesc *outDesc)
{
	if( (inStringRef == NULL) || (outDesc == NULL) )
		return paramErr;

	CFIndex uniCount = CFStringGetLength(inStringRef);
	const UniChar *uniString = CFStringGetCharactersPtr(inStringRef);

	if( uniString != NULL )
	{
		return AECreateDesc(typeUnicodeText, uniString, uniCount*sizeof(UniChar), outDesc);
	}

	UniChar* newString = (UniChar*)malloc(uniCount*sizeof(UniChar));
	if(newString == NULL)
		return memFullErr;

	CFRange theRange;
	theRange.location = 0;
	theRange.length = uniCount;
	CFStringGetCharacters( inStringRef, theRange, newString);
	OSStatus err = AECreateDesc(typeUnicodeText, newString, uniCount*sizeof(UniChar), outDesc);
	free(newString);
	return err;
}


//returns null if descriptior does not contain text
CFStringRef
CreateCFStringFromAEDesc(const AEDesc *inDesc)
{
	CFStringRef outString = NULL;
	if(inDesc == NULL || inDesc->dataHandle == NULL) 
		return NULL;
	
	Size byteCount = AEGetDescDataSize( inDesc );

	if( inDesc->descriptorType == typeCFStringRef )
	{
		AEGetDescData( inDesc, &outString, sizeof(CFStringRef) );
		//CFString ownership is passed to us, no need to retain
	}
	if( inDesc->descriptorType == typeUnicodeText )
	{
		UniChar *newBuffer = (UniChar *)NewPtrClear(byteCount);
		if(newBuffer != NULL)
		{
			if( AEGetDescData( inDesc, newBuffer, byteCount ) == noErr)
			{
				if( ((byteCount/sizeof(UniChar)) > 0) && (newBuffer[0] == 0xFEFF) )
				{
					newBuffer++;
					byteCount -= sizeof(UniChar);
				}
				outString = CFStringCreateWithCharacters(kCFAllocatorDefault, newBuffer, byteCount/sizeof(UniChar) );
			}	
			DisposePtr( (Ptr)newBuffer );
		}
	}
	else if( inDesc->descriptorType == typeChar )
	{
		char *newBuffer = NewPtrClear(byteCount);
		if(newBuffer != NULL)
		{
			if( AEGetDescData( inDesc, newBuffer, byteCount ) == noErr)
			{
				outString = CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8*)newBuffer, byteCount, CFStringGetSystemEncoding(), true);
			}	
			DisposePtr( (Ptr)newBuffer );
		}
	}
	else if( inDesc->descriptorType != typeNull ) 
	{
		AEDesc textDesc = {typeNull, NULL};
	
		if( AECoerceDesc( inDesc, typeUnicodeText, &textDesc ) == noErr)
		{
			if( (textDesc.descriptorType == typeUnicodeText) && (textDesc.dataHandle != NULL) )
			{
				byteCount = AEGetDescDataSize( &textDesc );
				UniChar *newBuffer = (UniChar *)NewPtrClear(byteCount);
				if(newBuffer != NULL)
				{
					if( AEGetDescData( &textDesc, newBuffer, byteCount ) == noErr)
					{
						if( ((byteCount/sizeof(UniChar)) > 0) && (newBuffer[0] == 0xFEFF) )
						{
							newBuffer++;
							byteCount -= sizeof(UniChar);
						}
						outString = CFStringCreateWithCharacters(kCFAllocatorDefault, newBuffer, byteCount/sizeof(UniChar) );
					}	
					DisposePtr( (Ptr)newBuffer );
				}
			}
		}
		else if( AECoerceDesc( inDesc, typeChar, &textDesc ) == noErr)
		{
			if( (textDesc.descriptorType == typeChar) && (textDesc.dataHandle != NULL) )
			{
				byteCount = AEGetDescDataSize( &textDesc );
				char *newBuffer = NewPtrClear(byteCount);
				if(newBuffer != NULL)
				{
					if( AEGetDescData( &textDesc, newBuffer, byteCount ) == noErr)
					{
						outString = CFStringCreateWithBytes(kCFAllocatorDefault, (const UInt8*)newBuffer, byteCount, CFStringGetSystemEncoding(), true);
					}	
					DisposePtr( (Ptr)newBuffer );
				}
			}
		}
		
		if(textDesc.dataHandle != NULL)
			AEDisposeDesc( &textDesc );
	}

	return outString;
}
