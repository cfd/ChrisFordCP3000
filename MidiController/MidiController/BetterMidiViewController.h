//
//  BetterMidiViewController.h
//  MidiController
//
//  Created by Chris on 22/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMIDI/CoreMIDI.h>


@interface BetterMidiViewController : UIViewController <NSNetServiceDelegate, NSNetServiceBrowserDelegate>{
    NSNetServiceBrowser *browser;
    NSMutableArray *services;
    
    MIDINetworkSession *session;
    MIDIEndpointRef destinationEndpoint;
    MIDIPortRef outputPort;
}

//-(void) resolveIPAddress:(NSNetService *)service;
//-(void) browseServices;

- (IBAction)handleKeyDown:(id)sender;
- (IBAction)handleKeyUp:(id)sender;

- (void) onChannel: (UInt8) chan
         startNote: (UInt8) note
      withVelocity: (UInt8) velocity;

- (void) onChannel: (UInt8) chan
          stopNote: (UInt8) note
      withVelocity: (UInt8) velocity;

- (void) search;
- (void) clearContacts;
- (void) resolveIPAddress:(NSNetService *)service;
- (void) configurePort;

+ (BetterMidiViewController*) getInstance;


@end
