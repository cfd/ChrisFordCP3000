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






@interface MusicDiscViewController : UIViewController <NSNetServiceDelegate, NSNetServiceBrowserDelegate>{
    NSNetServiceBrowser *browser;
    NSMutableArray *services;
    
    MIDINetworkSession *session;
    MIDIEndpointRef destinationEndpoint;
    MIDIPortRef outputPort;
    BOOL bPlaying;
    BOOL cPlaying;
    BOOL dPlaying;
    BOOL ePlaying;
    BOOL fPlaying;
    BOOL gPlaying;
    BOOL aPlaying;

    IBOutlet UILabel* aStatusLabel;
    IBOutlet UILabel* bStatusLabel;
    IBOutlet UILabel* cStatusLabel;
    IBOutlet UILabel* dStatusLabel;
    IBOutlet UILabel* eStatusLabel;
    IBOutlet UILabel* fStatusLabel;
    IBOutlet UILabel* gStatusLabel;
    
    IBOutlet UISlider* velocitySlider;
    
    UIColor* green;
    UIColor* white;
    UIColor* red;
    
    int velocity;
    
    
    
}


-(IBAction)sliderValueChanged:(id)sender;


-(void) sendMessage:(Byte)status withNote:(Byte)note withVelocity:(Byte)velocity;

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendPitchBendEvent:(Byte)msb lsb:(Byte)lsb;

-(void)changePointedNoteWithCurrent:(UILabel*)note;


- (void) search;
- (void) clearContacts;
- (void) resolveIPAddress:(NSNetService *)service;
- (void) configurePort;

+ (MusicDiscViewController*) getInstance;


@end
