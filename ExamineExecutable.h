/*
 *  ExamineExecutable.h
 *  Shortcuts
 *
 *  Created by Tomasz Kukielka on 4/12/09.
 *  Copyright 2009-2010 Abracode Inc. All rights reserved.
 *
 */
#ifndef _EXAMINE_EXECUTABLE_H_
#define _EXAMINE_EXECUTABLE_H_

#include <CoreFoundation/CoreFoundation.h>


enum
{
	kExecutableArchitecture_Invalid = 0,
	kExecutableArchitecture_Current,
	kExecutableArchitecture_PPC,
	kExcecutableArchitecture_i386,
	kExecutableArchitecture_PPC64,
	kExecutableArchitecture_x86_64
};

//returns any combination of the architectures above or kExecutableArchitecture_Invalid
int ExamineExecutable(CFURLRef inExecutableURLRef);

#endif //_EXAMINE_EXECUTABLE_H_