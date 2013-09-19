//
//  MIDIPianoViewController.m
//  MidiController
//
//  Created by Chris on 6/09/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "MusicCubeViewController.h"
#import "math.h"

@interface MusicCubeViewController ()

@end

static MusicCubeViewController* instance = nil;

@implementation MusicCubeViewController


static void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error); if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) { errorString[0] = errorString[5] = '\''; errorString[6] = '\0';
    } else {
        
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
        fprintf(stderr, "Error: %s (%s)\n", operation, errorString); exit(1);
    }
}


-(void) configurePort {
    
    session = [MIDINetworkSession defaultSession];
    if (session) {
        NSLog (@"Got MIDI session");
        //[session addConnection:connection]; session.enabled = YES;
        destinationEndpoint = [session destinationEndpoint];
        MIDIClientRef client = NULL;
        MIDIPortRef outport = NULL;
        CheckError (MIDIClientCreate(CFSTR("MyMIDIWifi Client"), NULL, NULL, &client), "Couldn't create MIDI client");
        CheckError (MIDIOutputPortCreate(client, CFSTR("MyMIDIWifi Output port"), &outport), "Couldn't create output port");
        outputPort = outport;
        NSLog (@"Got output port");
    }
}

-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser{
    NSLog(@"searching...");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
    @synchronized (session) {
        NSLog(@"found domain: %@", domainString);        // NOTE: you must create a new browser each time you search!
        if (!moreComing) {
            browser = [[NSNetServiceBrowser alloc] init];
            browser.delegate = self;
            [browser searchForServicesOfType:MIDINetworkBonjourServiceType inDomain:domainString];
        }
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    @synchronized (session) {
        if (!services) {
            services = [[NSMutableArray alloc] init];
        }
        NSLog(@"browser found service %@", aNetService.name);
        NSLog(@"more? %s",moreComing ? "yes" : "no");
        [services addObject:aNetService];
        [self resolveIPAddress:aNetService];
    }
}

-(void)resolveIPAddress:(NSNetService *)service {
    NSNetService *remoteService = service;
    remoteService.delegate = self;
    [remoteService resolveWithTimeout:10];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    @synchronized (session) {
        NSString *name = service.name;
        MIDINetworkHost* contact = [MIDINetworkHost hostWithName:name netService:service];
        
        // make sure the service is not already in the contacts list
        BOOL isNewContact = YES;
        
        NSSet* set = [[NSSet alloc] initWithSet:session.contacts];
        for (MIDINetworkHost* host in set)
        {
            if ([host.name caseInsensitiveCompare:name] == NSOrderedSame)
            {
                isNewContact = NO;
                break;
            }
        }
        
        // NOTE: dont add contact to the MIDI network itself! :)
        if (isNewContact && [name caseInsensitiveCompare:session.networkName] != NSOrderedSame) {
            
            NSLog(@"added contact: %@", name);
            [session addContact:contact];
            
        }
    }
}

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
    @synchronized (session) {
        NSLog(@"did not resolve net service %@ %@", service, errorDict);
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center postNotificationName:@"DidNotResolve"
                              object:self];
    }
}

- (void) search {
    [[MusicCubeViewController getInstance] clearContacts];
    browser = [[NSNetServiceBrowser alloc] init];
    browser.delegate = instance;
    [browser searchForRegistrationDomains];
}

- (void) clearContacts {
    NSLog(@"clearing contacts...");
    
    @synchronized (session) {
        NSSet* set = [[NSSet alloc] initWithSet:session.contacts];
        for (MIDINetworkHost* host in set)
        {
            NSLog(@"removed contact %@", [host name]);
            [session removeContact:host];
        }
    }
}

+ (MusicCubeViewController*)getInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MusicCubeViewController alloc] init];
    });
    return instance;
}

- (id) init {
    self = [super init];
    if (self) {
        browser = nil;
        session = [MIDINetworkSession defaultSession];
    }
    return self;
}


-(void) sendMessage:(Byte)command withNote:(Byte)note withVelocity:(Byte)vel {
    MIDIPacketList packetList;
    packetList.numPackets = 1;
    packetList.packet[0].length = 3;
    packetList.packet[0].data[0] = command;
    packetList.packet[0].data[1] = note;
    packetList.packet[0].data[2] = vel;
    packetList.packet[0].timeStamp = 0;
    CheckError (MIDISend(outputPort, destinationEndpoint, &packetList), "Couldn't send MIDI packet list");
}





-(IBAction)noteOnButtonOne:(id)sender{
    int midiNum = lowCMIDIConstant + buttonOneOffset;
    NSLog(@"%d ON", midiNum);
    [self sendNoteOnEvent:midiNum velocity:masterVelocity];
    buttonOnePlaying = YES;
}


-(IBAction)noteOffButtonOne:(id)sender{
    int midiNum = lowCMIDIConstant + buttonOneOffset;
    NSLog(@"%d OFF", midiNum);
    [self sendNoteOffEvent:midiNum velocity:masterVelocity];
    buttonOnePlaying = NO;
}

-(IBAction)noteOnButtonTwo:(id)sender{
    int midiNum = lowCMIDIConstant + buttonTwoOffset;
    NSLog(@"%d ON", midiNum);
    [self sendNoteOnEvent:midiNum velocity:masterVelocity];
    buttonTwoPlaying = YES;
}


-(IBAction)noteOffButtonTwo:(id)sender{
    int midiNum = lowCMIDIConstant + buttonTwoOffset;
    NSLog(@"%d OFF", midiNum);
    [self sendNoteOffEvent:midiNum velocity:masterVelocity];
    buttonTwoPlaying = NO;
}

-(IBAction)velocityChanged:(id)sender{
    masterVelocity = roundf(velocityControl.value);
    NSLog(@"vel: %d", masterVelocity);
}

-(IBAction)octaveChanged:(id)sender{
    
    if(buttonOnePlaying){
        switch (orientation) {
            case 1:
                [self sendNoteOffEvent:lowCMIDIConstant+10 velocity:masterVelocity];
                break;
            case 2:
                [self sendNoteOffEvent:lowCMIDIConstant+0 velocity:masterVelocity];
                break;
            case 3:
                [self sendNoteOffEvent:lowCMIDIConstant+6 velocity:masterVelocity];
                break;
            case 4:
                [self sendNoteOffEvent:lowCMIDIConstant+2 velocity:masterVelocity];
                break;
            case 5:
                [self sendNoteOffEvent:lowCMIDIConstant+8 velocity:masterVelocity];
                break;
            case 6:
                [self sendNoteOffEvent:lowCMIDIConstant+4 velocity:masterVelocity];
                break;
        }
        buttonOnePlaying = NO;
    }
    
    if(buttonTwoPlaying){
        switch (orientation) {
            case 1:
                [self sendNoteOffEvent:lowCMIDIConstant+11 velocity:masterVelocity];
                break;
            case 2:
                [self sendNoteOffEvent:lowCMIDIConstant+1 velocity:masterVelocity];
                break;
            case 3:
                [self sendNoteOffEvent:lowCMIDIConstant+7 velocity:masterVelocity];
                break;
            case 4:
                [self sendNoteOffEvent:lowCMIDIConstant+3 velocity:masterVelocity];
                break;
            case 5:
                [self sendNoteOffEvent:lowCMIDIConstant+9 velocity:masterVelocity];
                break;
            case 6:
                [self sendNoteOffEvent:lowCMIDIConstant+5 velocity:masterVelocity];
                break;
        }
        buttonTwoPlaying = NO;
    }

    
    
    NSString *selectedOctave = [octaveController titleForSegmentAtIndex:octaveController.selectedSegmentIndex];
    if([selectedOctave isEqualToString:@"C0"]){
        lowCMIDIConstant = 24;
    }
    else if([selectedOctave isEqualToString:@"C1"]){
        lowCMIDIConstant = 36;
    }
    else if([selectedOctave isEqualToString:@"C2"]){
        lowCMIDIConstant = 48;
    }
    else if([selectedOctave isEqualToString:@"C3"]){
        lowCMIDIConstant = 60;
    }
    else if([selectedOctave isEqualToString:@"C4"]){
        lowCMIDIConstant = 72;
    }
    else if([selectedOctave isEqualToString:@"C5"]){
        lowCMIDIConstant = 84;
    }
    else if([selectedOctave isEqualToString:@"C6"]){
        lowCMIDIConstant = 96;
    }
    
    
}


- (CMMotionManager *)motionManager{
    CMMotionManager *motionManager = nil;
    id appDelegate = [UIApplication sharedApplication].delegate;
    
    if([appDelegate respondsToSelector:@selector(motionManager)]) {
        motionManager = [appDelegate motionManager];
    }
    return motionManager;
}

- (void)startDeviceMotion{
    
    [self.motionManager startDeviceMotionUpdatesToQueue:[[NSOperationQueue alloc]init] withHandler:^(CMDeviceMotion *data,NSError *error)
     {
         CMAcceleration gravity = data.gravity;
         
         int gravX = roundf(gravity.x);
         int gravY = roundf(gravity.y);
         int gravZ = roundf(gravity.z);
         
         dispatch_async(dispatch_get_main_queue(), ^{
             //NSLog(@"%d %d %d", gravX, gravY, gravZ);
             
             
             switch(gravX){
                     
                 case 1:
                     if(orientation != 1){
                         orientation = 1;
                         if(prevOrientation != orientation){
                             [self orientationChanged:prevOrientation];
                             prevOrientation = 1;
                         }
                         [buttonOne setTitle:@"A # / B♭" forState:UIControlStateNormal];
                         [buttonTwo setTitle:@"B" forState:UIControlStateNormal];
                         buttonOneOffset = 10;
                         buttonTwoOffset = 11;
                     }
                     break;
                     
                 case -1:
                     if(orientation != 2){
                         orientation = 2;
                         if(prevOrientation != orientation){
                             [self orientationChanged:prevOrientation];
                             prevOrientation = 2;
                         }
                         [buttonOne setTitle:@"C" forState:UIControlStateNormal];
                         [buttonTwo setTitle:@"C # / D♭" forState:UIControlStateNormal];
                         buttonOneOffset = 0;
                         buttonTwoOffset = 1;
                     }
                     break;
             }
             
             
             switch(gravY){
                     
                 case 1:
                     if(orientation != 3){
                         orientation = 3;
                         if(prevOrientation != orientation){
                             [self orientationChanged:prevOrientation];
                             prevOrientation = 3;
                         }
                         [buttonOne setTitle:@"F # / G♭" forState:UIControlStateNormal];
                         [buttonTwo setTitle:@"G" forState:UIControlStateNormal];
                         buttonOneOffset = 6;
                         buttonTwoOffset = 7;
                     }
                     break;
                     
                 case -1:
                     if(orientation != 4){
                         orientation = 4;
                         if(prevOrientation != orientation){
                             [self orientationChanged:prevOrientation];
                             prevOrientation = 4;
                         }
                         [buttonOne setTitle:@"D" forState:UIControlStateNormal];
                         [buttonTwo setTitle:@"D # / E♭" forState:UIControlStateNormal];
                         buttonOneOffset = 2;
                         buttonTwoOffset = 3;
                     }
                     break;
                    
             }
             
             switch(gravZ){
                     
                 case 1:
                     if(orientation != 5){
                         orientation = 5;
                         if(prevOrientation != orientation){
                             [self orientationChanged:prevOrientation];
                             prevOrientation = 5;
                         }
                         [buttonOne setTitle:@"G # / A♭" forState:UIControlStateNormal];
                         [buttonTwo setTitle:@"A" forState:UIControlStateNormal];
                         
                         buttonOneOffset = 8;
                         buttonTwoOffset = 9;
                     }
                     break;
                     
                     
                 case -1:
                     if(orientation != 6){
                         orientation = 6;
                         if(prevOrientation != orientation){
                             [self orientationChanged:prevOrientation];
                             prevOrientation = 6;
                         }
                         
                         [buttonOne setTitle:@"E" forState:UIControlStateNormal];
                         [buttonTwo setTitle:@"F" forState:UIControlStateNormal];
                         buttonOneOffset = 4;
                         buttonTwoOffset = 5;
                     }
                     break;
                     
                     
             }
             
             
             //NSLog(@"current orientation: %d", orientation);
             
             
         });
         
         CMRotationRate rotRate = data.rotationRate;
         dispatch_async(dispatch_get_main_queue(), ^{
             
             int rotX = roundf(rotRate.x);
             int rotY = roundf(rotRate.y);
             int rotZ = roundf(rotRate.z);
             
             if(orientation == 1 || orientation == 2){
                 switch (rotX) {
                     case 10:
                         if(!bent){
                             [self sendPitchBendEvent:0 lsb:0];
                             bent = YES;
                         }
                         break;
                     case -10:
                         if(!bent){
                             [self sendPitchBendEvent:127 lsb:127];
                             bent = YES;
                         }
                         break;
                     case 6:
                         if(bent){
                             [self sendPitchBendEvent:64 lsb:64];
                             bent = NO;
                         }
                         break;
                 }
             }
             
             if(orientation == 3 || orientation == 4){
                 switch (rotY) {
                     case 10:
                         if(!bent){
                             [self sendPitchBendEvent:0 lsb:0];
                             bent = YES;
                         }
                         break;
                     case -10:
                         if(!bent){
                             [self sendPitchBendEvent:127 lsb:127];
                             bent = YES;
                         }
                         break;
                     case 6:
                         if(bent){
                             [self sendPitchBendEvent:64 lsb:64];
                             bent = NO;
                         }
                         break;
                 }
                 
                 
             }
             
             if(orientation == 5 || orientation == 6){
                 switch (rotZ) {
                     case 10:
                         if(!bent){
                             [self sendPitchBendEvent:0 lsb:0];
                             bent = YES;
                         }
                         break;
                     case -10:
                         if(!bent){
                             [self sendPitchBendEvent:127 lsb:127];
                             bent = YES;
                         }
                         break;
                     case 6:
                         if(bent){
                             [self sendPitchBendEvent:64 lsb:64];
                             bent = NO;
                         }
                         break;
                 }
             }
             
             
             });
     }];
    
    
}

-(void)orientationChanged:(int) prev{
    //NSLog(@"STATE CHANGE! with %d", prev);

    
    if(buttonOnePlaying){
        switch (prev) {
            case 1:
                [self sendNoteOffEvent:lowCMIDIConstant+10 velocity:masterVelocity];
                break;
            case 2:
                [self sendNoteOffEvent:lowCMIDIConstant+0 velocity:masterVelocity];
                break;
            case 3:
                [self sendNoteOffEvent:lowCMIDIConstant+6 velocity:masterVelocity];
                break;
            case 4:
                [self sendNoteOffEvent:lowCMIDIConstant+2 velocity:masterVelocity];
                break;
            case 5:
                [self sendNoteOffEvent:lowCMIDIConstant+8 velocity:masterVelocity];
                break;
            case 6:
                [self sendNoteOffEvent:lowCMIDIConstant+4 velocity:masterVelocity];
                break;
        }
        buttonOnePlaying = NO;
    }
    
    if(buttonTwoPlaying){
        switch (prev) {
            case 1:
                [self sendNoteOffEvent:lowCMIDIConstant+11 velocity:masterVelocity];
                break;
            case 2:
                [self sendNoteOffEvent:lowCMIDIConstant+1 velocity:masterVelocity];
                break;
            case 3:
                [self sendNoteOffEvent:lowCMIDIConstant+7 velocity:masterVelocity];
                break;
            case 4:
                [self sendNoteOffEvent:lowCMIDIConstant+3 velocity:masterVelocity];
                break;
            case 5:
                [self sendNoteOffEvent:lowCMIDIConstant+9 velocity:masterVelocity];
                break;
            case 6:
                [self sendNoteOffEvent:lowCMIDIConstant+5 velocity:masterVelocity];
                break;
        }
        buttonTwoPlaying = NO;
    }
}


- (void)updateOctaveLabels {
    //leftOctave.text = [NSString stringWithFormat:@"C%d", firstOctave];
    //rightOctave.text = [NSString stringWithFormat:@"C%d", (firstOctave+1)];
}

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)vel {
    [self sendMessage:0x90 withNote:note withVelocity:vel];
}

-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)vel {
    [self sendMessage:0x80 withNote:note withVelocity:vel];
}

-(void) sendPitchBendEvent:(Byte)msb lsb:(Byte)lsb {
    [self sendMessage:0xE0 withNote:msb withVelocity:lsb];
}



- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configurePort];
    [self search];
    
    UIColor *background = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"cubeBG4.png"]];
    self.view.backgroundColor = background;
    
    
    lowCMIDIConstant = 60;
    buttonOneOffset = 0;
    buttonTwoOffset = 0;
    prevOrientation = 0;
    orientation = 0;
    //firstOctave = 3;
    //leftOctave.text = @"C3";
    //rightOctave.text = @"C4";
    
    //[self setWantsFullScreenLayout:YES];
	// Do any additional setup after loading the view.
}


- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    masterVelocity = roundf(velocityControl.value);
    NSLog(@"vel: %d", masterVelocity);
    
    //octaveController.
    
    [self startDeviceMotion];
    //UIImage *image = [UIImage imageNamed:@"CubeButton.png"];
    //[buttonOne setBackgroundImage:image forState:UIControlStateNormal];
    //[buttonOne setAlpha:0.5];
    
}

- (void) viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.motionManager stopDeviceMotionUpdates];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
