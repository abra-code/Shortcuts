/*
 *  ExamineExecutable.c
 *  Shortcuts
 *
 *  Created by Tomasz Kukielka on 4/12/09.
 *  Copyright 2009-2010 Abracode Inc. All rights reserved.
 *
 */

#include "ExamineExecutable.h"
#include <mach-o/fat.h>
#include <mach-o/arch.h>
#include <mach-o/loader.h>


#define BYTES_TO_READ   512

/*  Byte-swaps an executable's header (which consists entirely of four-byte quantities on four-byte boundaries).
*/
static void swap_header(UInt8 *bytes, CFIndex length)
{
    CFIndex i;
    for (i = 0; i < length; i += 4)
		*(uint32_t *)(bytes + i) = OSSwapInt32(*(uint32_t *)(bytes + i));
}

/*  Determines whether an executable's header matches the current architecture, ppc, and/or i386. 
*   Returns true if the header corresponds to a Mach-O, 64-bit Mach-O, or universal binary executable, false otherwise.
*   Returns by reference the result of matching against a given architecture (matches_current, matches_ppc, matches_i386).
*   Checks for a given architecture only if the corresponding return-by-reference argument is non-NULL. 
*/
int ExamineExecutableHeader(UInt8 *bytes, CFIndex length)
{
    int matchedArchitectures = kExecutableArchitecture_Invalid;
    uint32_t magic = 0, num_fat = 0, max_fat = 0;
    struct fat_arch one_fat = {0}, *fat = NULL;
    const NXArchInfo *one_arch;
    
    // Look for any of the six magic numbers relevant to Mach-O executables, and swap the header if necessary.
    if (length >= sizeof(struct mach_header_64))
	{
        magic = *((uint32_t *)bytes);
        max_fat = (length - sizeof(struct fat_header)) / sizeof(struct fat_arch);
        if (MH_MAGIC == magic || MH_CIGAM == magic)
		{
            struct mach_header *mh = (struct mach_header *)bytes;
            if (MH_CIGAM == magic) swap_header(bytes, length);
            one_fat.cputype = mh->cputype;
            one_fat.cpusubtype = mh->cpusubtype;
            fat = &one_fat;
            num_fat = 1;
        }
		else if (MH_MAGIC_64 == magic || MH_CIGAM_64 == magic)
		{
            struct mach_header_64 *mh = (struct mach_header_64 *)bytes;
            if (MH_CIGAM_64 == magic) swap_header(bytes, length);
            one_fat.cputype = mh->cputype;
            one_fat.cpusubtype = mh->cpusubtype;
            fat = &one_fat;
            num_fat = 1;
        }
		else if (FAT_MAGIC == magic || FAT_CIGAM == magic)
		{
            fat = (struct fat_arch *)(bytes + sizeof(struct fat_header));
            if (FAT_CIGAM == magic) swap_header(bytes, length);
            num_fat = ((struct fat_header *)bytes)->nfat_arch;
            if (num_fat > max_fat)
				num_fat = max_fat;
        }
    }
    
    // Set the return value depending on whether the header appears valid.
    if((fat == NULL) || (num_fat == 0))
		return kExecutableArchitecture_Invalid;
	
    // Check for a match against the current architecture specification, if requested.
	one_arch = NXGetLocalArchInfo();
	if( (one_arch != NULL) && (NULL != NXFindBestFatArch(one_arch->cputype, one_arch->cpusubtype, fat, num_fat)) )
		matchedArchitectures |= kExecutableArchitecture_Current;

	one_arch = NXGetArchInfoFromName("ppc");
	if( (one_arch != NULL) && (NULL != NXFindBestFatArch(one_arch->cputype, one_arch->cpusubtype, fat, num_fat)) )
		matchedArchitectures |= kExecutableArchitecture_PPC;

	one_arch = NXGetArchInfoFromName("i386");
	if( (one_arch != NULL) && (NULL != NXFindBestFatArch(one_arch->cputype, one_arch->cpusubtype, fat, num_fat)) )
		matchedArchitectures |= kExcecutableArchitecture_i386;

	one_arch = NXGetArchInfoFromName("ppc64");
	if( (one_arch != NULL) && (NULL != NXFindBestFatArch(one_arch->cputype, one_arch->cpusubtype, fat, num_fat)) )
		matchedArchitectures |= kExecutableArchitecture_PPC64;

	one_arch = NXGetArchInfoFromName("x86_64");
	if( (one_arch != NULL) && (NULL != NXFindBestFatArch(one_arch->cputype, one_arch->cpusubtype, fat, num_fat)) )
		matchedArchitectures |= kExecutableArchitecture_x86_64;

    return matchedArchitectures;
}


int ExamineExecutable(CFURLRef inExecutableURLRef)
{
	if(inExecutableURLRef == NULL)
		return kExecutableArchitecture_Invalid;
	
	CFReadStreamRef readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, inExecutableURLRef);
	if(readStream == NULL)
		return kExecutableArchitecture_Invalid;
	
	UInt8 headerBuffer[BYTES_TO_READ];
	memset(headerBuffer, 0, sizeof(BYTES_TO_READ));

	int resultArchitectures = kExecutableArchitecture_Invalid;
	if( CFReadStreamOpen(readStream) )
	{
		CFIndex bytesRead = CFReadStreamRead(readStream, headerBuffer, BYTES_TO_READ);
		resultArchitectures = ExamineExecutableHeader(headerBuffer, bytesRead);
		CFReadStreamClose(readStream);
	}

	CFRelease(readStream);
	
	return resultArchitectures;
}
