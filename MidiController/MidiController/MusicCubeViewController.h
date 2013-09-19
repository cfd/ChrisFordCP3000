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


@interface MusicCubeViewController : UIViewController <NSNetServiceDelegate, NSNetServiceBrowserDelegate>{
    NSNetServiceBrowser *browser;
    NSMutableArray *services;
    
    MIDINetworkSession *session;
    MIDIEndpointRef destinationEndpoint;
    MIDIPortRef outputPort;
    
    
    IBOutlet UISlider *velocityControl;
    IBOutlet UILabel *leftOctave;
    IBOutlet UILabel *rightOctave;
    IBOutlet UIButton *buttonOne;
    IBOutlet UIButton *buttonTwo;
    IBOutlet UISegmentedControl *octaveController;
    
    //int firstOctave;
    int lowCMIDIConstant;
    int buttonOneOffset;
    int buttonTwoOffset;
    int masterVelocity;
    //BOOL bent;
    //BOOL moving;
    
    int prevOrientation;
    int orientation;
    
    BOOL buttonOnePlaying;
    BOOL buttonTwoPlaying;
    
    
}



-(void)orientationChanged:(int) prev;

-(void) sendMessage:(Byte)status withNote:(Byte)note withVelocity:(Byte)velocity;

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)velocity;
-(void) sendPitchBendEvent:(Byte)msb lsb:(Byte)lsb;

- (void) search;
- (void) clearContacts;
- (void) resolveIPAddress:(NSNetService *)service;
- (void) configurePort;

+ (MusicCubeViewController*) getInstance;




-(IBAction)noteOnButtonOne:(id)sender;
-(IBAction)noteOffButtonOne:(id)sender;
-(IBAction)noteOnButtonTwo:(id)sender;
-(IBAction)noteOffButtonTwo:(id)sender;

-(IBAction)octaveChanged:(id)sender;
-(IBAction)velocityChanged:(id)sender;





@end
