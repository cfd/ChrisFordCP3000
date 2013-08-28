//
//  BetterMidiViewController.h
//  MidiController
//
//  Created by Chris on 22/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMIDI/CoreMIDI.h>
#import <CoreMotion/CoreMotion.h>


@interface BetterMidiViewController : UIViewController <NSNetServiceDelegate, NSNetServiceBrowserDelegate>{
    NSNetServiceBrowser *browser;
    NSMutableArray *services;
    
    MIDINetworkSession *session;
    MIDIEndpointRef destinationEndpoint;
    MIDIPortRef outputPort;
}

-(void) sendMessage:(Byte)status withNote:(Byte)note withVelocity:(Byte)velocity;

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)velocity;

- (IBAction)handleKeyDown:(id)sender;
- (IBAction)handleKeyUp:(id)sender;



- (void) search;
- (void) clearContacts;
- (void) resolveIPAddress:(NSNetService *)service;
- (void) configurePort;

+ (BetterMidiViewController*) getInstance;


@end
