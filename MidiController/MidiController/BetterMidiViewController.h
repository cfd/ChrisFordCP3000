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

-(void) sendStatus:(Byte)status data1:(Byte)data1 data2:(Byte)data2;

-(void) sendNoteOnEvent:(Byte)key velocity:(Byte)velocity;
-(void) sendNoteOffEvent:(Byte)key velocity:(Byte)velocity;

- (IBAction)handleKeyDown:(id)sender;
- (IBAction)handleKeyUp:(id)sender;



- (void) search;
- (void) clearContacts;
- (void) resolveIPAddress:(NSNetService *)service;
- (void) configurePort;

+ (BetterMidiViewController*) getInstance;


@end
