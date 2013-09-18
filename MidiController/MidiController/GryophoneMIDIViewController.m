//
//  BetterMidiViewController.m
//  MidiController
//
//  Created by Chris on 22/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "GryophoneMIDIViewController.h"
#import "math.h"

@interface GyrophoneMIDIViewController ()

@end

static GyrophoneMIDIViewController* instance = nil;


@implementation GyrophoneMIDIViewController


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
    [[GyrophoneMIDIViewController getInstance] clearContacts];
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

+ (GyrophoneMIDIViewController*)getInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GyrophoneMIDIViewController alloc] init];
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

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)vel {
    [self sendMessage:0x90 withNote:note withVelocity:vel];
}
-(void) sendPitchBendEvent:(Byte)msb lsb:(Byte)lsb {
    [self sendMessage:0xE0 withNote:msb withVelocity:lsb];
}
-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)vel {
    [self sendMessage:0x80 withNote:note withVelocity:vel];
}

-(void) sendAllNotesOffEvent {
    [self sendMessage:176 withNote:123 withVelocity:127];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configurePort];
    [self search];
	// Do any additional setup after loading the view.
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
         CMAttitude *attitude = data.attitude;
         
         dispatch_async(dispatch_get_main_queue(), ^{
             //int pitch = roundf(attitude.pitch);
             //int roll = roundf(attitude.roll);
             //int yaw = roundf(attitude.yaw);
             //NSLog(@"%d   %d   %d", pitch, roll, yaw);
             //NSLog(@"%f", attitude.pitch);
             
             notePosition = [self roundYaw:attitude.yaw];
             //int noteControl = [self roundPitch:attitude.pitch];
             
             switch(notePosition){
                 case 1:
                     [self changePointedNoteWithCurrent:cStatusLabel];
                     break;
                 case 2:
                     [self changePointedNoteWithCurrent:cSharpStatusLabel];
                     break;
                     
                 case 3:
                     [self changePointedNoteWithCurrent:dStatusLabel];
                     break;
                     
                 case 4:
                     [self changePointedNoteWithCurrent:dSharpStatusLabel];
                     break;
                     
                 case 5:
                     [self changePointedNoteWithCurrent:eStatusLabel];
                     break;
                     
                 case 6:
                     [self changePointedNoteWithCurrent:fStatusLabel];
                     break;
                     
                 case 7:
                     [self changePointedNoteWithCurrent:fSharpStatusLabel];
                     break;
                     
                 case 8:
                     [self changePointedNoteWithCurrent:gStatusLabel];
                     break;
                     
                 case 9:
                     [self changePointedNoteWithCurrent:gSharpStatusLabel];
                     break;
                     
                 case 10:
                     [self changePointedNoteWithCurrent:aStatusLabel];
                     break;
                     
                 case 11:
                     [self changePointedNoteWithCurrent:aSharpStatusLabel];
                     break;
                     
                 case 12:
                     [self changePointedNoteWithCurrent:bStatusLabel];
                     break;
                     
                 default:
                     [self changePointedNoteWithCurrent:nil];
                     
             }
             
             
//             switch(noteControl){
//                 case 1:
//                     switch(notePosition){
//                         case 1:
//                             if(!cPlaying){
//                                 cPlaying = YES;
//                                 cStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:60 velocity:masterVelocity];
//                             }
//                             break;
//                         case 2:
//                             if(!cSharpPlaying){
//                                 cSharpPlaying = YES;
//                                 cSharpStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:61 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 3:
//                             if(!dPlaying){
//                                 dPlaying = YES;
//                                 dStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:62 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 4:
//                             if(!dSharpPlaying){
//                                 dSharpPlaying = YES;
//                                 dSharpStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:63 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 5:
//                             if(!ePlaying){
//                                 ePlaying = YES;
//                                 eStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:64 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 6:
//                             if(!fPlaying){
//                                 fPlaying = YES;
//                                 fStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:65 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 7:
//                             if(!fSharpPlaying){
//                                 fSharpPlaying = YES;
//                                 fSharpStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:66 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 8:
//                             if(!gPlaying){
//                                 gPlaying = YES;
//                                 gStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:67 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 9:
//                             if(!gSharpPlaying){
//                                 gSharpPlaying = YES;
//                                 gSharpStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:68 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 10:
//                             if(!aPlaying){
//                                 aPlaying = YES;
//                                 aStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:69 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 11:
//                             if(!aSharpPlaying){
//                                 aSharpPlaying = YES;
//                                 aSharpStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:70 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 12:
//                             if(!bPlaying){
//                                 bPlaying = YES;
//                                 bStatusLabel.textColor = green;
//                                 [self sendNoteOnEvent:71 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                     }
//                     break;
//                 case 2:
//                     switch(notePosition){
//                         case 1:
//                             if(cPlaying){
//                                 cPlaying = NO;
//                                 cStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:60 velocity:masterVelocity];
//                             }
//                             break;
//                         case 2:
//                             if(cSharpPlaying){
//                                 cSharpPlaying = NO;
//                                 cSharpStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:61 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 3:
//                             if(dPlaying){
//                                 dPlaying = NO;
//                                 dStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:62 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 4:
//                             if(dSharpPlaying){
//                                 dSharpPlaying = NO;
//                                 dSharpStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:63 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 5:
//                             if(ePlaying){
//                                 ePlaying = NO;
//                                 eStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:64 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 6:
//                             if(fPlaying){
//                                 fPlaying = NO;
//                                 fStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:65 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 7:
//                             if(fSharpPlaying){
//                                 fSharpPlaying = NO;
//                                 fSharpStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:66 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 8:
//                             if(gPlaying){
//                                 gPlaying = NO;
//                                 gStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:67 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 9:
//                             if(gSharpPlaying){
//                                 gSharpPlaying = NO;
//                                 gSharpStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:68 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 10:
//                             if(aPlaying){
//                                 aPlaying = NO;
//                                 aStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:69 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 11:
//                             if(aSharpPlaying){
//                                 aSharpPlaying = NO;
//                                 aSharpStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:70 velocity:masterVelocity];
//                             }
//                             break;
//                             
//                         case 12:
//                             if(bPlaying){
//                                 bPlaying = NO;
//                                 bStatusLabel.textColor = white;
//                                 [self sendNoteOffEvent:71 velocity:masterVelocity];
//                             }
//                             
//                     }
//                     break;
//                     
//             }
             
         });
     }];
}

-(IBAction)playButtonPressed:(id)sender{
    [self sendNoteOnEvent:60+notePosition-1 velocity:masterVelocity];
}


-(IBAction)playButtonReleased:(id)sender{
    [self sendNoteOffEvent:60+notePosition-1 velocity:masterVelocity];
    
}

//-(int)roundPitch:(float)pitch{
//    NSLog(@"%f", pitch);
//    int onOffNumber=0;
//    
//    if(pitch >= 0.3){
//        onOffNumber = 2;
//    }
//    else if(pitch <= -0.3){
//        onOffNumber = 1;
//    }
//    NSLog(@"%d", onOffNumber);
//    return onOffNumber;
//}

-(int)roundYaw:(float)yaw{
    //NSLog(@"%f", yaw);
    int noteRefNumber=0;
    if(yaw >= -1.002 && yaw < -0.835){
        noteRefNumber = 12;
    }
    else if(yaw >= -0.835 && yaw < -0.668){
        noteRefNumber = 11;
    }
    else if(yaw >= -0.668 && yaw < -0.501){
        noteRefNumber = 10;
    }
    else if(yaw >= -0.501 && yaw < -0.334){
        noteRefNumber = 9;
    }
    else if(yaw >= -0.334 && yaw < -0.167){
        noteRefNumber = 8;
    }
    else if(yaw >= -0.167 && yaw < 0){
        noteRefNumber = 7;
    }
    else if(yaw >= 0 && yaw < 0.167){
        noteRefNumber = 6;
    }
    else if(yaw >= 0.167 && yaw < 0.334){
        noteRefNumber = 5;
    }
    else if(yaw >= 0.334 && yaw < 0.501){
        noteRefNumber = 4;
    }
    else if(yaw >= 0.501 && yaw < 0.668){
        noteRefNumber = 3;
    }
    else if(yaw >= 0.668 && yaw < 0.835){
        noteRefNumber = 2;
    }
    else if(yaw >= 0.835 && yaw < 1.002){
        noteRefNumber = 1;
    }
    
    
    //NSLog(@"%d", noteRefNumber);
    return noteRefNumber;
}

-(void)changePointedNoteWithCurrent:(UILabel*)note{
    cStatusLabel.backgroundColor = nil;
    cSharpStatusLabel.backgroundColor = nil;
    dStatusLabel.backgroundColor = nil;
    dSharpStatusLabel.backgroundColor = nil;
    eStatusLabel.backgroundColor = nil;
    fStatusLabel.backgroundColor = nil;
    fSharpStatusLabel.backgroundColor = nil;
    gStatusLabel.backgroundColor = nil;
    gSharpStatusLabel.backgroundColor = nil;
    aStatusLabel.backgroundColor = nil;
    aSharpStatusLabel.backgroundColor = nil;
    bStatusLabel.backgroundColor = nil;
    
    note.backgroundColor = red;
    
    
}




- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startDeviceMotion];
    green = [UIColor colorWithRed:0 green:255 blue:0 alpha:1];
    white = [UIColor colorWithRed:255 green:255 blue:255 alpha:1];
    red = [UIColor colorWithRed:255 green:0 blue:0 alpha:1];
    
    NSLog(@"Motion updates began");
    
    //masterVelocity = roundf(velocitySlider.value);
    masterVelocity = 127;
}



- (IBAction)velocityChanged:(id)sender{
    masterVelocity = roundf(velocitySlider.value);
    //NSLog(@"value is now %d", velocity);
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
