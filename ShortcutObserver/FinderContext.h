/*
 *  FinderContext.h
 *  ShortcutObserver
 *
 *  Created by Tom on 2/27/05.
 *  Copyright 2005 Abracode. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

#if __cplusplus
extern "C"
#endif
OSStatus CreateFinderContext(const ProcessSerialNumber *inProcessSN, AEDesc *outContext);
