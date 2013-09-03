//
//  BetterMidiViewController.m
//  MidiController
//
//  Created by Chris on 22/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "MusicDiscViewController.h"
#import "math.h"

@interface MusicDiscViewController ()

@end

static MusicDiscViewController* instance = nil;


@implementation MusicDiscViewController


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
    [[MusicDiscViewController getInstance] clearContacts];
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

+ (MusicDiscViewController*)getInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MusicDiscViewController alloc] init];
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


-(void) sendMessage:(Byte)command withNote:(Byte)note withVelocity:(Byte)velocity {
    MIDIPacketList packetList;
    packetList.numPackets = 1;
    packetList.packet[0].length = 3;
    packetList.packet[0].data[0] = command;
    packetList.packet[0].data[1] = note;
    packetList.packet[0].data[2] = velocity;
    packetList.packet[0].timeStamp = 0;
    CheckError (MIDISend(outputPort, destinationEndpoint, &packetList), "Couldn't send MIDI packet list");
}

-(void) sendNoteOnEvent:(Byte)note velocity:(Byte)velocity {
    [self sendMessage:0x90 withNote:note withVelocity:velocity];
}
-(void) sendNoteOffEvent:(Byte)note velocity:(Byte)velocity {
    [self sendMessage:0x80 withNote:note withVelocity:velocity];
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
    //    __block float stepMoveFactor = 15;
    
    [self.motionManager startDeviceMotionUpdatesToQueue:[[NSOperationQueue alloc]init] withHandler:^(CMDeviceMotion *data,NSError *error)
     {
         CMAttitude *attitude = data.attitude;
         dispatch_async(dispatch_get_main_queue(), ^{
             int pitch = roundf(attitude.pitch);
             int roll = roundf(attitude.roll);
             int yaw = roundf(attitude.yaw);
             NSLog(@"%d   %d   %d", pitch, roll, yaw);
             //NSLog(cPlaying ? @"Yes" : @"No");
             //       NSLog(@"%d", (int)grav.x);
             
             switch(pitch){
                     
                 case 1:
                     
                     switch(yaw){
                             
                         case 0:
                             if(!aPlaying){
                                 aPlaying = YES;
                                 aStatusLabel.textColor = green;
                                 [self sendNoteOnEvent:57 velocity:127];
                             }
                             break;
                             
                         case -1:
                             if(!bPlaying){
                                 bPlaying = YES;
                                 bStatusLabel.textColor = green;
                                 [self sendNoteOnEvent:59 velocity:127];
                             }
                             break;
                             
                         case -2:
                             if(!cPlaying){
                                 cPlaying = YES;
                                 cStatusLabel.textColor = green;
                                 [self sendNoteOnEvent:60 velocity:127];
                             }
                             break;
                             
                         case -3:
                             if(!dPlaying){
                                 dPlaying = YES;
                                 dStatusLabel.textColor = green;
                                 [self sendNoteOnEvent:62 velocity:127];
                             }
                             break;
                             
                         case 3:
                             if(!ePlaying){
                                 ePlaying = YES;
                                 eStatusLabel.textColor = green;
                                 [self sendNoteOnEvent:64 velocity:127];
                             }
                             break;
                             
                         case 2:
                             if(!fPlaying){
                                 fPlaying = YES;
                                 fStatusLabel.textColor = green;
                                 [self sendNoteOnEvent:65 velocity:127];
                             }
                             break;
                             
                         case 1:
                             if(!gPlaying){
                                 gPlaying = YES;
                                 gStatusLabel.textColor = green;
                                 [self sendNoteOnEvent:67 velocity:127];
                             }
                             break;
                             
                     }

                     
                     break;
                     
                 case -1:
                     switch(yaw){
                             
                         case 0:
                             if(aPlaying){
                                 aPlaying = NO;
                                 aStatusLabel.textColor = white;
                                 [self sendNoteOffEvent:57 velocity:127];
                             }
                             break;
                             
                         case -1:
                             if(bPlaying){
                                 bPlaying = NO;
                                 bStatusLabel.textColor = white;
                                 [self sendNoteOffEvent:59 velocity:127];
                             }
                             break;
                             
                         case -2:
                             if(cPlaying){
                                 cPlaying = NO;
                                 cStatusLabel.textColor = white;
                                 [self sendNoteOffEvent:60 velocity:127];
                             }
                             break;
                             
                         case -3:
                             if(dPlaying){
                                 dPlaying = NO;
                                 dStatusLabel.textColor = white;
                                 [self sendNoteOffEvent:62 velocity:127];
                             }
                             break;
                             
                         case 3:
                             if(ePlaying){
                                 ePlaying = NO;
                                 eStatusLabel.textColor = white;
                                 [self sendNoteOffEvent:64 velocity:127];
                             }
                             break;
                             
                         case 2:
                             if(fPlaying){
                                 fPlaying = NO;
                                 fStatusLabel.textColor = white;
                                 [self sendNoteOffEvent:65 velocity:127];
                             }
                             break;
                             
                         case 1:
                             if(gPlaying){
                                 gPlaying = NO;
                                 gStatusLabel.textColor = white;
                                 [self sendNoteOffEvent:67 velocity:127];
                             }
                             break;
                             
                     }
                     break;                     

             }
//             
//             switch(roll){
//                     
//                 case 1:
//                     if(!dPlaying){
//                         dPlaying = YES;
//                         [self sendNoteOnEvent:62 velocity:127];
//                     }
//                     break;
//                     
//                 case -1:
//                     if(!gPlaying){
//                         gPlaying = YES;
//                         [self sendNoteOnEvent:67 velocity:127];
//                     }
//                     break;
//                     
//                 case 0:
//                     if(dPlaying){
//                         dPlaying = NO;
//                         [self sendNoteOffEvent:62 velocity:127];
//                     }
//                     if(gPlaying){
//                         gPlaying = NO;
//                         [self sendNoteOffEvent:67 velocity:127];
//                     }
//                     break;
//                     
//             }
             
             switch(yaw){
                     
                 case 0:
                     noteLabel.text = @"A";
                     break;
                     
                 case -1:
                     noteLabel.text = @"B";
                     break;
                     
                 case -2:
                     noteLabel.text = @"C";
                     break;
                     
                 case -3:
                     noteLabel.text = @"D";
                     break;
                     
                 case 3:
                     noteLabel.text = @"E";
                     break;
                     
                 case 2:
                     noteLabel.text = @"F";
                     break;
                     
                 case 1:
                     noteLabel.text = @"G";
                     break;
                     
             }
             
             
             //             if(grav.x){
             //                 [self sendNoteOnEvent:60 velocity:127];
             //             }
             
         });
         
//         CMRotationRate rotRate = data.rotationRate;
//         dispatch_async(dispatch_get_main_queue(), ^{
//             
//             int rotX = roundf(rotRate.x);
//             int rotY = roundf(rotRate.y);
//             int rotZ = roundf(rotRate.z);
//             NSLog(@"%d   %d   %d", rotX, rotY, rotZ);
//             
//             if(cPlaying || ePlaying){
//                 switch (rotX) {
//                     case 5:
//                         [self sendMessage:224 withNote:0 withVelocity:0];
//                         break;
//                         
//                     case -5:
//                         [self sendMessage:224 withNote:127 withVelocity:127];
//                         break;
//                         
//                     case 0:
//                         [self sendMessage:224 withNote:64 withVelocity:64
//                          ];;
//                         NSLog(@"reset X");
//                         break;
//                         
//                     default:
//                         
//                         break;
//                 }
//             }
//             
//             if(dPlaying || gPlaying){
//                 switch (rotY) {
//                     case 5:
//                         [self sendMessage:224 withNote:0 withVelocity:0];
//                         break;
//                         
//                     case -5:
//                         [self sendMessage:224 withNote:127 withVelocity:127];
//                         break;
//                         
//                     case 0:
//                         [self sendMessage:224 withNote:64 withVelocity:64];;
//                         NSLog(@"reset Y");
//                         break;
//                         
//                     default:
//                         
//                         break;
//                 }
//             }
//             
//             if(aPlaying){
//                 switch (rotZ) {
//                     case 5:
//                         [self sendMessage:224 withNote:0 withVelocity:0];
//                         break;
//                         
//                     case -5:
//                         [self sendMessage:224 withNote:127 withVelocity:127];
//                         break;
//                         
//                     case 0:
//                         [self sendMessage:224 withNote:64 withVelocity:64];
//                         NSLog(@"reset Z");
//                         break;
//                         
//                     default:
//                         
//                         break;
//                 }
//             }
//             
//         });
         
     }];
    
    
}




- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startDeviceMotion];
    green = [UIColor colorWithRed:0 green:255 blue:0 alpha:1];
    white = [UIColor colorWithRed:255 green:255 blue:255 alpha:1];
    
    NSLog(@"Motion updates began");
    
    
    
    
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
