//
//  TwoOSixPMController.m
//  206PM
//
//  Created by Abimanyu on 1/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "TwoOSixPMController.h"

#define ITUNES_TRACK_CHANGED	@"Changed Tracks"
#define ITUNES_PAUSED			@"Paused"
#define ITUNES_STOPPED			@"Stopped"
#define ITUNES_PLAYING			@"Started Playing"

#define ITUNES_APP_NAME         @"iTunes.app"
#define ITUNES_BUNDLE_ID        @"com.apple.itunes"
#define APP_PATH @"/Applications/206PM.app"

@implementation TwoOSixPMController


- (void)enableLoginItemWithLoginItemsReference:(LSSharedFileListRef )theLoginItemsRefs ForPath:(CFURLRef)thePath {
	// We call LSSharedFileListInsertItemURL to insert the item at the bottom of Login Items list.
	LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(theLoginItemsRefs, kLSSharedFileListItemLast, NULL, NULL, thePath, NULL, NULL);		
	if (item)
		CFRelease(item);
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification {
	
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:APP_PATH];
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	[self enableLoginItemWithLoginItemsReference:loginItems ForPath:url];
	CFRelease(loginItems);
	
	[self createStatusItem];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(songChanged:)
															name:@"com.apple.iTunes.playerInfo"
														  object:nil];
}

#pragma mark -
#pragma mark iTunes 4.7 notifications

- (BOOL)isSameDay:(NSDate*)date1 otherDay:(NSDate*)date2 {
    NSCalendar* calendar = [NSCalendar currentCalendar];
	
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
    NSDateComponents* comp1 = [calendar components:unitFlags fromDate:date1];
    NSDateComponents* comp2 = [calendar components:unitFlags fromDate:date2];
	
    return [comp1 day]   == [comp2 day] &&
    [comp1 month] == [comp2 month] &&
    [comp1 year]  == [comp2 year];
}


- (void) writeToLogFile:(NSString *)text{
	
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	
	
	NSDate *today = [NSDate date];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	// display in 12HR/24HR (i.e. 11:25PM or 23:25) format according to User Settings
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	NSString *currentTime = [dateFormatter stringFromDate:today];
	
	NSDate *oldday = [standardUserDefaults objectForKey:@"today"];
	
	NSString *filepath = [NSString stringWithFormat:@"%@/music.txt", NSHomeDirectory()];
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filepath];
	if(!fileHandle){
		[[NSFileManager defaultManager] createFileAtPath: filepath
												contents: nil attributes: nil];
		fileHandle = [NSFileHandle fileHandleForWritingAtPath:filepath];
	}
	
	if([self isSameDay:today otherDay:oldday]){
		//Do nothing
	}else{
		
		NSDateFormatter *dateFormatter2 = [[NSDateFormatter alloc] init];
		// display in 12HR/24HR (i.e. 11:25PM or 23:25) format according to User Settings
		[dateFormatter2 setDateStyle:NSDateFormatterMediumStyle];
		
		NSString *textToWrite = [[NSString alloc] initWithFormat:@"\n%@ \n\n", [dateFormatter2 stringFromDate:today]];
		
		[fileHandle seekToEndOfFile];
		[fileHandle writeData:[textToWrite dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	if (standardUserDefaults) {
		[standardUserDefaults setObject:today forKey:@"today"];
	}
	
			
	[dateFormatter release];
	
	NSString *textToWrite = [[NSString alloc] initWithFormat:@"%@  %@ \n", currentTime , text];
	
	[fileHandle seekToEndOfFile];
	[fileHandle writeData:[textToWrite dataUsingEncoding:NSUTF8StringEncoding]];
	[fileHandle closeFile];
}

- (void) songChanged:(NSNotification *)aNotification {
	NSString     *playerState = nil;
	iTunesState   newState    = itUNKNOWN;
	NSString     *newTrackURL = nil;
	NSDictionary *userInfo    = [aNotification userInfo];
	
	playerState = [[aNotification userInfo] objectForKey:@"Player State"];
	if ([playerState isEqualToString:@"Paused"]) {
		newState = itPAUSED;
		//NSLog(@"Paused");
		[self writeToLogFile:@"Paused"];
	} else if ([playerState isEqualToString:@"Stopped"]) {
		//NSLog(@"Stopped");
		newState = itSTOPPED;
		//[noteDict release];
		//noteDict = nil;
		[self writeToLogFile:@"Stopped"];
	} else if ([playerState isEqualToString:@"Playing"]){
		newState = itPLAYING;
		/*For radios and files, the ID is the location.
		 *For iTMS purchases, it's the Store URL.
		 *For Bonjour shares, we'll hash a compilation of a bunch of info.
		 */
		if ([userInfo objectForKey:@"Location"]) {
			newTrackURL = [userInfo objectForKey:@"Location"];
		} else if ([userInfo objectForKey:@"Store URL"]) {
			newTrackURL = [userInfo objectForKey:@"Store URL"];
		} else {
			/*Get all the info we can, in such a way that the empty fields are
			 *	blank rather than (null).
			 *Then we hash it and turn that into our identifier string.
			 *That way a track name of "file://foo" won't confuse our code later on.
			 */
			NSArray *keys = [[NSArray alloc] initWithObjects:@"Name", @"Artist",
							 @"Album", @"Composer", @"Genre", @"Year", @"Track Number",
							 @"Track Count", @"Disc Number", @"Disc Count", @"Total Time",
							 @"Stream Title", nil];
			NSArray *args = [userInfo objectsForKeys:keys notFoundMarker:@""];
			[keys release];
			newTrackURL = [args componentsJoinedByString:@"|"];
			newTrackURL = [[NSNumber numberWithUnsignedLong:[newTrackURL hash]] stringValue];
		}
	}
	
	if (newTrackURL) {
		NSString		*track         = nil;
		NSString		*artist        = @"";
		
		artist      = [userInfo objectForKey:@"Artist"];
		
		if ([userInfo objectForKey:@"Track Number"]) {
			track = [[NSString alloc] initWithFormat:@"%@ by %@", [userInfo objectForKey:@"Name"], artist];
		} else {
			//track number is nil for radio streams, ignore it
			track = [userInfo objectForKey:@"Name"];
		}
		
		if(!artist){
			artist = @"Unknown";
		}
		NSString *tr = [[NSString alloc] initWithFormat:@"%@ by %@", [userInfo objectForKey:@"Name"], artist];
		//[tr appendString:@"\n"];
		//NSLog(@"track: %@", tr);
		
		[self writeToLogFile:tr];
		
		// set up us some state for next time
		state = newState;
		[trackURL release];
		trackURL = [newTrackURL retain];
		[lastPostedDescription release];
	}
}


#pragma mark Status item

- (void) createStatusItem {
	NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
	statusItem = [[statusBar statusItemWithLength:NSSquareStatusItemLength] retain];
	if (statusItem) {
		[statusItem setMenu:[self statusItemMenu]];
		[statusItem setHighlightMode:YES];
		[statusItem setImage:[NSImage imageNamed:@"growlTunes.png"]];
		[statusItem setAlternateImage:[NSImage imageNamed:@"growlTunes-selected.png"]];
		[statusItem setToolTip:NSLocalizedString(@"2:06 PM", /*comment*/ nil)];
	}
}

- (NSMenu *) statusItemMenu {
	//NSLog(@"In statusItemMenu");
	NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"TwoOSixPM"];
	if (menu) {
		NSMenuItem * item;
		NSString *empty = @""; //used for the key equivalent of all the menu items.
		
		item = [menu addItemWithTitle:NSLocalizedString(@"Open Music Log", @"") action:@selector(openTextFile:) keyEquivalent:empty];
		[item setTarget:self];
		
		item = [menu addItemWithTitle:NSLocalizedString(@"About 2:06PM", @"") action:@selector(openAboutPage:) keyEquivalent:empty];
		[item setTarget:self];
		
		item = [menu addItemWithTitle:NSLocalizedString(@"Quit 2:06PM", @"") action:@selector(quit206AM:) keyEquivalent:empty];
		[item setTarget:self];
		
	}
	
	return [menu autorelease];
}


- (IBAction) openTextFile:(id)sender{
	NSString *filepath = [NSString stringWithFormat:@"%@/music.txt", NSHomeDirectory()];
	[[NSWorkspace sharedWorkspace] openFile:filepath];
}

- (IBAction) quit206AM:(id)sender {
	[NSApp terminate:sender];
}

- (IBAction) openAboutPage:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://blog.abi.sh/2010/206pm/"]];
}

@end
