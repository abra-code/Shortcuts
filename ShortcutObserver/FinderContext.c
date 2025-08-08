/*
 *  Finder.c
 *  ShortcutObserver
 *
 *  Created by Tom on 2/27/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include "FinderContext.h"
//pascal Boolean MoreAESimpleIdleFunction(EventRecord* event, long* sleepTime, RgnHandle* mouseRgn);
//static AEIdleUPP gAEIdleUPP = nil;

OSErr GetFinderObjectAsAlias(const AEDesc *finderAddress,
							const AEDesc* inObjAEDesc,
							AEDesc* outAliasAEDesc);

OSStatus GetFinderInsertionLocationAsAliasDesc(const AEDesc *finderAddress, AEDesc *outAliasDesc);

OSErr MoreAEOCreatePropertyObject( const DescType pPropertyType,
								AEDesc *pContainerAEDesc,
								AEDesc *propertyObjPtr );


OSErr MoreAETellAppObjectToGetAEDesc(	const AEDesc *appAddress,
										AEDesc *containerObj,
										const DescType pPropType,
										const DescType pDescType,
										AEDesc *pAEDesc);

/*OSStatus MoreAECreateAppleEventCreatorTarget(
							const AEEventClass pAEEventClass,
							const AEEventID pAEEventID,
							const OSType pCreator,
							AppleEvent* pAppleEvent);
*/

OSErr	MoreAEGetHandlerError(const AppleEvent* pAEReply);

OSErr MoreAESendEventReturnAEDesc(
						const AppleEvent	*pAppleEvent,
						const DescType		pDescType,
						AEDesc				*pAEDesc);

//caller responsible for releasing non-null *outContext
OSStatus
CreateFinderContext(const ProcessSerialNumber *inProcessSN, AEDesc *outContext)
{
	AEDesc appAddress = {typeNull, nil};//to release
	AEDesc appleEvent = {typeNull, nil};//to release
	AppleEvent theReply = {typeNull,nil};//to release

	OSStatus err = noErr;

//	if (nil == gAEIdleUPP)
//		gAEIdleUPP = NewAEIdleUPP(MoreAESimpleIdleFunction);

	err = AECreateDesc(typeProcessSerialNumber, inProcessSN,
							sizeof(ProcessSerialNumber), &appAddress);
	if(err != noErr)
	{
#if _DEBUG_
		printf("Shortcut Observer->CreateFinderContext. AECreateDesc for ProcessSerialNumber returned error = %d\n", (int)err);
#endif
		return err;
	}

	//appAddress to release

	err = AECreateAppleEvent(
						kAECoreSuite, kAEGetData,
						&appAddress,
						kAutoGenerateReturnID,
						kAnyTransactionID,
						&appleEvent);

	if(err != noErr)
	{
#if _DEBUG_
		printf("Shortcut Observer->CreateFinderContext. AECreateAppleEvent for kAEGetData returned error = %d\n", (int)err);
#endif
		AEDisposeDesc(&appAddress);
		return err;
	}

	//appleEvent to release
	
	AEDesc containerObj = {typeNull, nil};//null container object means app itself
	AEDesc selObject = {typeNull, nil};

	err = MoreAEOCreatePropertyObject( pSelection,
										&containerObj,
										&selObject);
	if(noErr != err)
	{
#if _DEBUG_
		printf("Shortcut Observer->CreateFinderContext. MoreAEOCreatePropertyObject for pSelection returned error = %d\n", (int)err);
#endif
		AEDisposeDesc(&appAddress);
		AEDisposeDesc(&appleEvent);
		return err;
	}

	
	err = AEPutParamDesc(&appleEvent, keyDirectObject, &selObject);
	if(noErr != err)
	{
#if _DEBUG_
		printf("Shortcut Observer->CreateFinderContext. AEPutParamDesc with keyDirectObject returned error = %d\n", (int)err);
#endif
		AEDisposeDesc(&appAddress);
		AEDisposeDesc(&appleEvent);
		return err;
	}

	err = AESend(&appleEvent, &theReply, kAEWaitReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);	
	if( (err == noErr) && (theReply.descriptorType != typeNull) )
	{
		//theReply to release
		DescType actualType;
		long actualSize;
		OSErr handlerErr = noErr;
		OSErr tempErr = AEGetParamPtr( &theReply, keyErrorNumber, typeSInt16, &actualType,
								&handlerErr, sizeof(OSErr), &actualSize );
		if(tempErr != errAEDescNotFound)// found error
			err = handlerErr;
		if(err == noErr)
		{
			AEDesc theObjList = {typeNull, nil};;
			err = AEGetParamDesc(&theReply, keyDirectObject, typeAEList, &theObjList);
			if((err == noErr) && (theObjList.descriptorType == typeAEList))
			{//now we got a list of Finder objects but unfortunately
			//Finder objects are not very useful and cannot be coerced to aliases without Finder's help
			//so we take objects one by one from the list and ask Finder to create alias description for it
			//the new alias description is put into final result list
				long itemsCount = 0;
				err = AECountItems(&theObjList, &itemsCount);
				if( (err == noErr) && (itemsCount > 0) )
				{
					AEDesc oneItem;
					AEDesc aliasDesc;
					SInt32 i;
					err = AECreateList(NULL, 0, false, outContext);
					for(i = 1; i <= itemsCount; i++)
					{
						AEKeyword theKeyword;
						err = AEGetNthDesc(&theObjList, i, typeWildCard, &theKeyword, &oneItem);
						if(err == noErr)
						{
							err = GetFinderObjectAsAlias(&appAddress, &oneItem, &aliasDesc);
							if(err == noErr)
							{
								err = AEPutDesc (outContext, 0, &aliasDesc);
								AEDisposeDesc(&aliasDesc);
							}
							else
							{
#if _DEBUG_
								printf("Shortcut Observer->CreateFinderContext. GetFinderObjectAsAlias returned error = %d\n", (int)err);
#endif				
							}
						}
						else
						{
#if _DEBUG_
							printf("Shortcut Observer->CreateFinderContext. AEGetNthDesc with typeWildCard returned error = %d\n", (int)err);
#endif				
						}
					}
				}
				else
				{
#if _DEBUG_
					printf("Shortcut Observer->CreateFinderContext. AECountItems returned error = %d or 0 items, trying insert location\n", (int)err);
#endif			
					AEDesc aliasDesc;
					err = GetFinderInsertionLocationAsAliasDesc(&appAddress, &aliasDesc);
					if(err == noErr)
					{
						err = AECreateList(NULL, 0, false, outContext);
						if(err == noErr)
							err = AEPutDesc (outContext, 0, &aliasDesc);
						AEDisposeDesc(&aliasDesc);
					}
					else
					{
#if _DEBUG_
						printf("Shortcut Observer->CreateFinderContext. GetFinderInsertionLocationAsAliasDesc returned error = %d\n", (int)err);
#endif				
					}
				}
			}
			else
			{
#if _DEBUG_
				printf("Shortcut Observer->CreateFinderContext. AEGetParamDesc with keyDirectObject, typeAEList returned error = %d or not typeAEList\n", (int)err);
#endif
			}
		}
		else
		{
#if _DEBUG_
			printf("Shortcut Observer->CreateFinderContext. AEGetParamPtr for keyErrorNumber returned error = %d\n", (int)err);
#endif
		}

		AEDisposeDesc(&theReply);
	}
	else
	{
#if _DEBUG_
		printf("Shortcut Observer->CreateFinderContext. AESend returned error = %d or descriptor type is NULL\n", (int)err);
#endif
	}

	AEDisposeDesc(&appAddress);
	AEDisposeDesc(&appleEvent);
	
	return err;
}


//caller responsible for releasing outAliasAEDesc

OSErr
GetFinderObjectAsAlias(const AEDesc *finderAddress, const AEDesc* inObjAEDesc, AEDesc* outAliasAEDesc)
{
	OSErr err = noErr;
	AppleEvent appleEvent = {typeNull, NULL};
	AppleEvent theReply  = {typeNull, NULL};

	if ((nil == finderAddress) || (nil == inObjAEDesc) || (nil == outAliasAEDesc))
		return paramErr;

	if (typeObjectSpecifier != inObjAEDesc->descriptorType)
		return paramErr;	// this has to be an object specifier

	
	err = AECreateAppleEvent(
						kAECoreSuite, kAEGetData,
						finderAddress,
						kAutoGenerateReturnID,
						kAnyTransactionID,
						&appleEvent);

	if(err != noErr)
		return err;
	
	//appleEvent to release

	err = AEPutParamDesc(&appleEvent, keyDirectObject, inObjAEDesc);
	if(noErr == err)
	{
		DescType aliasDescType = typeAlias;
		err = AEPutKeyPtr(&appleEvent, keyAERequestedType, typeType, &aliasDescType, sizeof(DescType));
		if(noErr == err)
		{
			err = AESend(&appleEvent, &theReply, kAEWaitReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
			if((err == noErr) && (theReply.descriptorType != typeNull))
			{
				//theReply to release
				DescType	actualType;
				long		actualSize;
				OSErr		handlerErr = noErr;
				OSErr tempErr = AEGetParamPtr( &theReply, keyErrorNumber, typeSInt16, &actualType,
										&handlerErr, sizeof(OSErr), &actualSize );
				if(tempErr != errAEDescNotFound)// found an errorNumber parameter
					err = handlerErr;
				if(err == noErr)
					err = AEGetParamDesc(&theReply, keyDirectObject, typeAlias, outAliasAEDesc);
				AEDisposeDesc(&theReply);
			}
		}
	}
	AEDisposeDesc(&appleEvent);

	return err;
}

OSStatus
GetFinderInsertionLocationAsAliasDesc(const AEDesc *finderAddress, AEDesc *outAliasDesc)
{
	OSErr err = noErr;
	AEDesc finderObj = {typeNull, NULL};
	AEDesc containerObj = {typeNull, NULL};//null container - app object
	err = MoreAETellAppObjectToGetAEDesc( finderAddress, &containerObj,
										pInsertionLoc, typeWildCard, &finderObj);
	if(err == noErr)
		err = GetFinderObjectAsAlias(finderAddress, &finderObj, outAliasDesc);

	AEDisposeDesc( &finderObj );
	
	return err;
}


OSErr
MoreAEOCreatePropertyObject( const DescType pPropertyType,
											 AEDesc *pContainerAEDesc,
											 AEDesc *propertyObjPtr )
{
	OSErr	anErr = noErr;
	AEDesc	propDesc = {typeNull, NULL};
	
	anErr = AECreateDesc( typeType, &pPropertyType, sizeof(pPropertyType), &propDesc );
	if ( noErr == anErr )
	{
		anErr = CreateObjSpecifier( cProperty, pContainerAEDesc, formPropertyID,
									&propDesc, false, propertyObjPtr );
		AEDisposeDesc( &propDesc );
	}
	
	return anErr;
}//end MoreAEOCreatePropertyObject

/*
OSStatus MoreAECreateAppleEventCreatorTarget(
							const AEEventClass pAEEventClass,
							const AEEventID pAEEventID,
							const OSType pCreator,
							AppleEvent* pAppleEvent)
{
	OSStatus 	anErr;
	AEDesc 		targetDesc = {typeNull, NULL};
	
	if(pAppleEvent == NULL)
		return paramErr;
	
	anErr = AECreateDesc(typeApplSignature, &pCreator, sizeof(pCreator), &targetDesc);
	if (noErr == anErr)
		anErr = AECreateAppleEvent(pAEEventClass, pAEEventID, &targetDesc, 
									kAutoGenerateReturnID, kAnyTransactionID, pAppleEvent);
	AEDisposeDesc(&targetDesc);
	
	return anErr;
}//end MoreAECreateAppleEventCreatorTarget
*/

OSErr MoreAETellAppObjectToGetAEDesc(	const AEDesc *appAddress,
										AEDesc *containerObj,
										const DescType pPropType,
										const DescType pDescType,
										AEDesc *pAEDesc)
{
	AppleEvent tAppleEvent = {typeNull, NULL};
	OSErr anErr = noErr;

	anErr = AECreateAppleEvent(kAECoreSuite, kAEGetData, appAddress,  kAutoGenerateReturnID, kAnyTransactionID,  &tAppleEvent);
	if(noErr == anErr)
	{
		AEDesc propertyObject = {typeNull, NULL};
		anErr = MoreAEOCreatePropertyObject(pPropType, containerObj, &propertyObject);
		if(noErr == anErr)
		{
			anErr = AEPutParamDesc(&tAppleEvent, keyDirectObject, &propertyObject);
			if(noErr == anErr)
				anErr = MoreAESendEventReturnAEDesc(&tAppleEvent, pDescType, pAEDesc);
		
			AEDisposeDesc(&propertyObject);
		}
		
		AEDisposeDesc(&tAppleEvent);
	}
	return anErr;
}


OSErr MoreAESendEventReturnAEDesc(
						const AppleEvent	*pAppleEvent,
						const DescType		pDescType,
						AEDesc				*pAEDesc)
{
	OSErr anErr = noErr;
	AppleEvent theReply = {typeNull, NULL};
	AESendMode sendMode = kAEWaitReply;

	anErr = AESend(pAppleEvent, &theReply, sendMode, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
	if (noErr == anErr)
	{
		anErr = MoreAEGetHandlerError(&theReply);

		if( (anErr == noErr) && theReply.descriptorType != typeNull )
		{
			anErr = AEGetParamDesc(&theReply, keyDirectObject, pDescType, pAEDesc);
		}
		AEDisposeDesc(&theReply);
	}
	return anErr;
}	// MoreAESendEventReturnAEDesc

OSErr	MoreAEGetHandlerError(const AppleEvent* pAEReply)
{
	OSErr		anErr = noErr;
	OSErr		handlerErr;
	
	DescType	actualType;
	long		actualSize;
	
	if ( pAEReply->descriptorType != typeNull )	// there's a reply, so there may be an error
	{
		OSErr	getErrErr = noErr;
		
		getErrErr = AEGetParamPtr( pAEReply, keyErrorNumber, typeSInt16, &actualType,
									&handlerErr, sizeof( OSErr ), &actualSize );
		
		if ( getErrErr != errAEDescNotFound )	// found an errorNumber parameter
		{
			anErr = handlerErr;					// so return it's value
		}
	}
	return anErr;
}//end MoreAEGetHandlerError