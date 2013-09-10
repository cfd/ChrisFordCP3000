//
//  MIDIPianoViewController.h
//  MidiController
//
//  Created by Chris on 6/09/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMIDI/CoreMIDI.h>
#import <CoreMotion/CoreMotion.h>


@interface MIDIPianoViewController : UIViewController <NSNetServiceDelegate, NSNetServiceBrowserDelegate>{
    NSNetServiceBrowser *browser;
    NSMutableArray *services;
    
    MIDINetworkSession *session;
    MIDIEndpointRef destinationEndpoint;
    MIDIPortRef outputPort;
    
    
    IBOutlet UISlider *velocityControl;
    IBOutlet UILabel *leftOctave;
    IBOutlet UILabel *rightOctave;
    
    int firstOctave;
    int lowCMIDIConstant;
    int masterVelocity;
    BOOL bent;
    BOOL moving;
    
    
}




-(void) sendMessage:(Byte)status withNote:(Byte)note withVelocity:(Byte)velocity;

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendPitchBendEvent:(Byte)msb lsb:(Byte)lsb;

- (void) search;
- (void) clearContacts;
- (void) resolveIPAddress:(NSNetService *)service;
- (void) configurePort;

+ (MIDIPianoViewController*) getInstance;

    
    

-(IBAction)noteOn:(id)sender;
-(IBAction)noteOff:(id)sender;

-(IBAction)VelocityChanged:(id)sender;





@end
