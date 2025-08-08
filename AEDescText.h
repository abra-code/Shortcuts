/*
 *  AEDescText.h
 *  Shortcuts
 *
 *  Created by Tom on 5/28/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include <CoreServices/CoreServices.h>

#ifdef __cplusplus
extern "C" {
#endif


CFStringRef CreateCFStringFromAEDesc(const AEDesc *inDesc);
OSStatus CreateUniTextDescFromCFString(CFStringRef inStringRef, AEDesc *outDesc);

#ifdef __cplusplus
}
#endif


