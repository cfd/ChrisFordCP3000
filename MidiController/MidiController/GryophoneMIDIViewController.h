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






@interface GyrophoneMIDIViewController : UIViewController <NSNetServiceDelegate, NSNetServiceBrowserDelegate>{
    NSNetServiceBrowser *browser;
    NSMutableArray *services;
    
    MIDINetworkSession *session;
    MIDIEndpointRef destinationEndpoint;
    MIDIPortRef outputPort;
    
    BOOL cPlaying;
    BOOL cSharpPlaying;
    BOOL dPlaying;
    BOOL dSharpPlaying;
    BOOL ePlaying;
    BOOL fPlaying;
    BOOL fSharpPlaying;
    BOOL gPlaying;
    BOOL gSharpPlaying;
    BOOL aPlaying;
    BOOL aSharpPlaying;
    BOOL bPlaying;
    
    
    IBOutlet UILabel* cStatusLabel;
    IBOutlet UILabel* cSharpStatusLabel;
    IBOutlet UILabel* dStatusLabel;
    IBOutlet UILabel* dSharpStatusLabel;
    IBOutlet UILabel* eStatusLabel;
    IBOutlet UILabel* fStatusLabel;
    IBOutlet UILabel* fSharpStatusLabel;
    IBOutlet UILabel* gStatusLabel;
    IBOutlet UILabel* gSharpStatusLabel;
    IBOutlet UILabel* aStatusLabel;
    IBOutlet UILabel* aSharpStatusLabel;
    IBOutlet UILabel* bStatusLabel;

    IBOutlet UISlider* velocitySlider;
    
    UIColor* green;
    UIColor* white;
    UIColor* red;
    
    int masterVelocity;
    int notePosition;
    
    
    
}

-(IBAction)playButtonPressed:(id)sender;

-(IBAction)velocityChanged:(id)sender;


-(void) sendMessage:(Byte)status withNote:(Byte)note withVelocity:(Byte)velocity;

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendPitchBendEvent:(Byte)msb lsb:(Byte)lsb;

-(void)changePointedNoteWithCurrent:(UILabel*)note;


- (void) search;
- (void) clearContacts;
- (void) resolveIPAddress:(NSNetService *)service;
- (void) configurePort;


+ (GyrophoneMIDIViewController*) getInstance;


@end
