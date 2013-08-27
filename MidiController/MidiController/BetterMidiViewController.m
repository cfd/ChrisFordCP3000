//
//  BetterMidiViewController.m
//  MidiController
//
//  Created by Chris on 22/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "BetterMidiViewController.h"

@interface BetterMidiViewController ()

@end

static BetterMidiViewController* instance = nil;


@implementation BetterMidiViewController


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
    [[BetterMidiViewController getInstance] clearContacts];
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

+ (BetterMidiViewController*)getInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BetterMidiViewController alloc] init];
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

- (IBAction)handleKeyDown:(id)sender{
    printf("midiNumberDown: %d", [sender tag]);
    [self sendNoteOnEvent:(Byte) [sender tag] velocity:127];
    
    
}
- (IBAction)handleKeyUp:(id)sender{
    printf("midiNumberUp: %d", [sender tag]);
    [self sendNoteOffEvent:(Byte) [sender tag] velocity:127];
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

- (void)startAccelerometer{
    //    __block float stepMoveFactor = 15;
    
    [self.motionManager startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc]init] withHandler:^(CMAccelerometerData *data,NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
             //printf("AccX: %f\nAccY: %f\nAccZ: %f\r\n", data.acceleration.x, data.acceleration.y, data.acceleration.z);
//             accX.text = [NSString stringWithFormat:@"X: %f", data.acceleration.x];
//             accY.text = [NSString stringWithFormat:@"Y: %f", data.acceleration.y];
//             accZ.text = [NSString stringWithFormat:@"Z: %f", data.acceleration.z];
             
             NSLog(@"X:%d", ABS((int)data.acceleration.x));
             int accX = ABS((int)data.acceleration.x);
             switch (accX)
             
             {
                 case 1:
                     
                     [self sendNoteOnEvent:60 velocity:127];
                     
                     break;
                     
                 case 2:
                     [self sendNoteOffEvent:60 velocity:127];
                     [self sendNoteOnEvent:62 velocity:127];
                     
                     break;
                     
                 case 3:
                     [self sendNoteOffEvent:62 velocity:127];
                     [self sendNoteOnEvent:64 velocity:127];
                     
                     break;
                     
                 default:
                     
                     [self sendNoteOffEvent:60 velocity:127];
                     [self sendNoteOffEvent:62 velocity:127];
                     [self sendNoteOffEvent:64 velocity:127];
                     
                     break;
                     
             }
         });
     }];
}

/*
 JASON: Is this the point - to have notes say C-B on say accelerometer and the gyro can change the pitch (midi equivilent velocity? what is velocity???  volume?)
 Also i never specified a channel? say what?
 
 i gather if motion is constantly sampled... then its ok to send messages constantly? :/ but I don't really know how to send stop messages with the motion stuff :'(
 
 */


- (void)startGyroscope{
    //    __block float stepMoveFactor = 15;
    
    [self.motionManager startGyroUpdatesToQueue:[[NSOperationQueue alloc]init] withHandler:^(CMGyroData *data,NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
             //printf("GyroX: %f\nGyroY: %f\nGyroZ: %f\r\n", data.rotationRate.x, data.rotationRate.y, data.rotationRate.z);
//             gyroX.text = [NSString stringWithFormat:@"X: %f", data.rotationRate.x];
//             gyroY.text = [NSString stringWithFormat:@"Y: %f", data.rotationRate.y];
//             gyroZ.text = [NSString stringWithFormat:@"Z: %f", data.rotationRate.z];
             
             //NSLog(@"X: %f", data.rotationRate.x);
//             if(ABS(data.rotationRate.x)>1 && ABS(data.rotationRate.x)<2){
//                 [self sendNoteOnEvent:(Byte) 60 velocity:127];
//                 NSLog(@"low C");
//             }else if(ABS(data.rotationRate.x)>2 && ABS(data.rotationRate.x)<3){
//                 [self sendNoteOffEvent:(Byte) 60 velocity:127];
//                 [self sendNoteOnEvent:(Byte) 72 velocity:127];
//                 NSLog(@"high C on | low C off" );
//             }else if(ABS(data.rotationRate.x)>0 && ABS(data.rotationRate.x)<1){
//                 [self sendNoteOffEvent:(Byte) 60 velocity:127];
//                 [self sendNoteOnEvent:(Byte) 72 velocity:127];
//                 NSLog(@"high C on | low C off" );
//             }
             
             
                 
             
         });
     }];
}



- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startAccelerometer];
    //[self startGyroscope];
}

- (void) viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.motionManager stopAccelerometerUpdates];
    //[self.motionManager stopGyroUpdates];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
