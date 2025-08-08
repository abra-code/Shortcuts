//
//  HotKeyListController.m
//  Shortcuts

extern CFStringRef kShortcutObserverPortName;

extern const UniChar kCmdGlyph;
extern const UniChar kOptionGlyph;
extern const UniChar kControlGlyph;
extern const UniChar kShiftGlyph;

enum
{
	kMessagePrefsChanged = 1
};


#import "HotKeyListController.h"
#include "ShortcutList.h"

@implementation HotKeyListController

- (void)awakeFromNib
{
	[mShortcutTableView noteNumberOfRowsChanged];
	[mShortcutTableView deselectAll:self];
	[mShortcutTableView setTarget:self];
	[mShortcutTableView setDoubleAction: @selector(editShortcut:) ];

	if(mEditButton != NULL)
		[mEditButton setEnabled:FALSE];
	
	if(mRemoveButton != NULL)
		[mRemoveButton setEnabled:FALSE];
}

#pragma mark -
#pragma mark === DATA SOURCE ===

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	CFMutableArrayRef shortcutList = NULL;
	if(mShortcutsController != NULL)
		shortcutList = [mShortcutsController getShortcutList];
	if(shortcutList != NULL)
		return CFArrayGetCount(shortcutList);
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{    
	CFMutableArrayRef shortcutList = NULL;
	if(mShortcutsController != NULL)
		shortcutList = [mShortcutsController getShortcutList];

    if( shortcutList != NULL )
	{
		CFIndex	theCount = CFArrayGetCount(shortcutList);
		if( (row >= 0) && (row < theCount) )
		{
			NSString *identifier = [tableColumn identifier];
			
			if([identifier isEqualToString:@"MenuName"])
			{
				//return @"MenuName";
			
				CFTypeRef theItem = CFArrayGetValueAtIndex(shortcutList, row);
				if( (theItem != NULL) && (CFGetTypeID(theItem) == CFDictionaryGetTypeID()) )
				{
					CFDictionaryRef theDict = (CFDictionaryRef)theItem;
					CFTypeRef theResult = CFDictionaryGetValue( theDict, CFSTR("NAME") );
					if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
					{
						NSString * __weak theName = (__bridge NSString *)theResult;
						theResult = CFDictionaryGetValue( theDict, CFSTR("SUBMENU") );
						if((theResult != NULL) && (CFStringGetTypeID() == CFGetTypeID(theResult)) )
						{
							NSString * __weak submenuPath = (__bridge NSString *)theResult;
							NSMutableString *outStr = [NSMutableString stringWithString:submenuPath];
                            NSUInteger strLen = [outStr length];
							if( (strLen > 0) && [outStr characterAtIndex:(strLen-1)] != '/' )
								[outStr appendString:@"/"];
							[outStr appendString:theName];
							return outStr;
						}
						else
							return theName;
					}
				}
			
			}
			else if([identifier isEqualToString:@"HotKey"])
			{
				CFStringRef keyChar = NULL;
				CFIndex carbonModifiers = 0;
				CFIndex keyCode = 0;
				FetchShortcutKeyAndModifiers(shortcutList, row,
								&keyChar, &carbonModifiers, &keyCode);
								
				unsigned int modifiers = [ShortcutsController getModifiersFromCarbonModifiers: carbonModifiers];
				NSString *shortcutString = [ShortcutsController getShortHotKeyString:(__bridge NSString *)keyChar withModifiers:modifiers];
				if(shortcutString != NULL)
					return shortcutString;
			}
		}
	}
	return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
/*
	int selectedShortcutIndex = [mShortcutTableView selectedRow];
	if((selectedShortcutIndex < 0) || (selectedShortcutIndex >= theCount) )
		return;
*/	

	int selectedCount = [mShortcutTableView numberOfSelectedRows];
	if(selectedCount == 1)
	{
         if(mEditButton != NULL)
            [mEditButton setEnabled:YES];
	
        if(mRemoveButton != NULL)
            [mRemoveButton setEnabled:YES];	
	}
	else if(selectedCount > 1)
	{
         if(mEditButton != NULL)
            [mEditButton setEnabled:FALSE];
	
        if(mRemoveButton != NULL)
            [mRemoveButton setEnabled:YES];
	}
	else
	{
         if(mEditButton != NULL)
            [mEditButton setEnabled:FALSE];
	
        if(mRemoveButton != NULL)
            [mRemoveButton setEnabled:FALSE];
	}
}

- (IBAction)editShortcut:(id)sender
{
	int numberOfSelectedRows = [mShortcutTableView numberOfSelectedRows];
	if(numberOfSelectedRows == 1)
	{
		int selectedShortcutIndex = [mShortcutTableView selectedRow];
		if(mShortcutsController != NULL)
		{
			[mShortcutsController editItem:(CFIndex)selectedShortcutIndex];
		}
	}
}

- (IBAction)removeShortcut:(id)sender
{
	int numberOfSelectedRows = [mShortcutTableView numberOfSelectedRows];
    if(numberOfSelectedRows == 0)
        return;

	CFMutableArrayRef shortcutList = NULL;
	if(mShortcutsController != NULL)
		shortcutList = [mShortcutsController getShortcutList];

    NSArray *sortedIndexes = [[[mShortcutTableView selectedRowEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)];
    unsigned indexCount = [sortedIndexes count];

    int firstIndex = -1;
    if(indexCount > 0)
    {
		NSNumber *theNum = (NSNumber *)[sortedIndexes objectAtIndex:0];
		firstIndex = [theNum intValue];
    }
	int i;
    for(i = indexCount-1; i >= 0; i--)
    {
        NSNumber *theNum = (NSNumber *)[sortedIndexes objectAtIndex:i];
        int theIndex = [theNum intValue];
		if((theIndex >= 0) && (theIndex < CFArrayGetCount(shortcutList)))
			CFArrayRemoveValueAtIndex( shortcutList, theIndex );
    }

    [mShortcutTableView reloadData];

    CFIndex newCount =  CFArrayGetCount(shortcutList);

    if(newCount == 0)
		firstIndex = -1;

    if(firstIndex == -1)
        [mShortcutTableView deselectAll:self];
    else if((firstIndex-1) >= 0)
        [mShortcutTableView selectRow:(firstIndex-1) byExtendingSelection:NO];
    else if((firstIndex >= 0) && ((unsigned)firstIndex < newCount))
        [mShortcutTableView selectRow:firstIndex byExtendingSelection:NO];
    else
        [mShortcutTableView deselectAll:self];

	if(mShortcutsController != NULL)
		[mShortcutsController savePreferences:self];
}

@end
