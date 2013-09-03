//
//  BetterMidiViewController.m
//  MidiController
//
//  Created by Chris on 22/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "CubeWithAttitudeViewController.h"
#import "math.h"

@interface CubeWithAttitudeViewController ()

@end

static CubeWithAttitudeViewController* instance = nil;


@implementation CubeWithAttitudeViewController


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
    [[CubeWithAttitudeViewController getInstance] clearContacts];
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

+ (CubeWithAttitudeViewController*)getInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CubeWithAttitudeViewController alloc] init];
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
         CMAcceleration grav = data.gravity;
         dispatch_async(dispatch_get_main_queue(), ^{
             int gravX = roundf(grav.x);
             int gravY = roundf(grav.y);
             int gravZ = roundf(grav.z);
             //NSLog(@"%d   %d   %d", gravX, gravY, gravZ);
             //NSLog(cPlaying ? @"Yes" : @"No");
             //       NSLog(@"%d", (int)grav.x);
             
             switch(gravX){
                     
                 case 1:
                     if(!ePlaying){
                         ePlaying = YES;
                         [self sendNoteOnEvent:64 velocity:127];
 
                     }
                     break;
                     
                 case -1:
                     if(!cPlaying){
                         cPlaying = YES;
                         [self sendNoteOnEvent:60 velocity:127];
                     }
                     break;
                     
                 case 0:
                     if(ePlaying){
                         ePlaying = NO;
                         [self sendNoteOffEvent:64 velocity:127];
                     }
                     if(cPlaying){
                         cPlaying = NO;
                         [self sendNoteOffEvent:60 velocity:127];
                     }
                     break;
                     
                     CMAttitude *attitude = data.attitude;
                     dispatch_async(dispatch_get_main_queue(), ^{
                         
                         int rotPitch = roundf(attitude.pitch);
                         int rotRoll = roundf(attitude.roll);
                         int rotYaw = roundf(attitude.yaw);
                         NSLog(@"%d   %d   %d", rotPitch, rotRoll, rotYaw);
                         
                     
                     });
                     
                     
             }
             
             switch(gravY){
                     
                 case 1:
                     if(!dPlaying){
                         dPlaying = YES;
                         [self sendNoteOnEvent:62 velocity:127];
                     }
                     break;
                     
                 case -1:
                     if(!gPlaying){
                         gPlaying = YES;
                         [self sendNoteOnEvent:67 velocity:127];
                     }
                     break;
                     
                 case 0:
                     if(dPlaying){
                         dPlaying = NO;
                         [self sendNoteOffEvent:62 velocity:127];
                     }
                     if(gPlaying){
                         gPlaying = NO;
                         [self sendNoteOffEvent:67 velocity:127];
                     }
                     break;
                     
                     CMAttitude *attitude = data.attitude;
                     dispatch_async(dispatch_get_main_queue(), ^{
                         
                         int rotPitch = roundf(attitude.pitch);
                         int rotRoll = roundf(attitude.roll);
                         int rotYaw = roundf(attitude.yaw);
                         NSLog(@"%d   %d   %d", rotPitch, rotRoll, rotYaw);
                         
                         
                     });
             }
             
             switch(gravZ){
                     
                 case 1:
                     if(!aPlaying){
                         aPlaying = YES;
                         [self sendNoteOnEvent:69 velocity:127];
                     }
                     break;
                     
                     
                 case 0:
                     if(aPlaying){
                         aPlaying = NO;
                         [self sendNoteOffEvent:69 velocity:127];
                     }
                     break;
                     
                     CMAttitude *attitude = data.attitude;
                     dispatch_async(dispatch_get_main_queue(), ^{
                         
                         int rotPitch = roundf(attitude.pitch);
                         int rotRoll = roundf(attitude.roll);
                         int rotYaw = roundf(attitude.yaw);
                         NSLog(@"%d   %d   %d", rotPitch, rotRoll, rotYaw);
                         
                         
                     });
             
             }
             
             
             //             if(grav.x){
             //                 [self sendNoteOnEvent:60 velocity:127];
             //             }
             
         });
         
         CMAttitude *attitude = data.attitude;
         dispatch_async(dispatch_get_main_queue(), ^{
             
             int rotPitch = roundf(attitude.pitch);
             int rotRoll = roundf(attitude.roll);
             int rotYaw = roundf(attitude.yaw);
             NSLog(@"%d   %d   %d", rotPitch, rotRoll, rotYaw);
             
             if(cPlaying || ePlaying){
                 switch (rotYaw) {
                     case 1:
                         [self sendMessage:224 withNote:0 withVelocity:0];
                         break;
                         
                     case -1:
                         [self sendMessage:224 withNote:127 withVelocity:127];
                         break;
                         
                     case 0:
                         [self sendMessage:224 withNote:64 withVelocity:64
                          ];;
                         NSLog(@"reset X");
                         break;
                         
                     default:
                         
                         break;
                 }
             }
             
             if(dPlaying || gPlaying){
                 switch (rotRoll) {
                     case 1:
                         [self sendMessage:224 withNote:0 withVelocity:0];
                         break;
                         
                     case -1:
                         [self sendMessage:224 withNote:127 withVelocity:127];
                         break;
                         
                     case 0:
                         [self sendMessage:224 withNote:64 withVelocity:64];;
                         NSLog(@"reset Y");
                         break;
                         
                     default:
                         
                         break;
                 }
             }
             
             if(aPlaying){
                 switch (rotYaw) {
                     case 1:
                         [self sendMessage:224 withNote:0 withVelocity:0];
                         break;
                         
                     case -1:
                         [self sendMessage:224 withNote:127 withVelocity:127];
                         break;
                         
                     case 0:
                         [self sendMessage:224 withNote:64 withVelocity:64];
                         NSLog(@"reset Z");
                         break;
                         
                     default:
                         
                         break;
                 }
             }
             
         });
         
     }];
    
    
}




- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startDeviceMotion];
    
    
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
