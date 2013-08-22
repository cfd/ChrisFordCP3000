//
//  SetupController.h
//  iPerform
//
//  Created by Jason Holdsworth on 11/04/11.
//  Copyright 2011 NerdJam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@interface MIDINetworkDiscovery
: NSObject <NSNetServiceDelegate, NSNetServiceBrowserDelegate> {
    
@private NSNetServiceBrowser* browser;
    
}

- (void) search;
- (void) clearContacts;

+ (MIDINetworkDiscovery*) getInstance;

@end
