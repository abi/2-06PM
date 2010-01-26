//
//  TestController.h
//  206PM
//
//  Created by Abimanyu on 1/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef enum {
	itPLAYING,
	itPAUSED,
	itSTOPPED,
	itUNKNOWN
} iTunesState;

@interface TwoOSixPMController : NSObject {
	NSStatusItem	*statusItem;
	iTunesState			state;
	NSString			*trackURL;		//The file location of the last-known track in iTunes, @"" for none
	NSString			*lastPostedDescription;
}


#pragma mark Status item

//- (void) createStatusItem;
//- (NSMenu *) statusItemMenu;


@end

