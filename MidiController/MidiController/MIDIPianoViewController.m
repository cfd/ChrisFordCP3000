//
//  MIDIPianoViewController.m
//  MidiController
//
//  Created by Chris on 6/09/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "MIDIPianoViewController.h"
#import "math.h"

@interface MIDIPianoViewController ()

@end

static MIDIPianoViewController* instance = nil;

@implementation MIDIPianoViewController


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
    [[MIDIPianoViewController getInstance] clearContacts];
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

+ (MIDIPianoViewController*)getInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MIDIPianoViewController alloc] init];
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





-(IBAction)noteOn:(id)sender{
    int midiNum = lowCMIDIConstant + [sender tag];
    NSLog(@"%d ON", midiNum);
    [self sendNoteOnEvent:midiNum velocity:masterVelocity];
}


-(IBAction)noteOff:(id)sender{
    int midiNum = lowCMIDIConstant + [sender tag];
    NSLog(@"%d OFF", midiNum);
    [self sendNoteOffEvent:midiNum velocity:masterVelocity];
}

-(IBAction)VelocityChanged:(id)sender{
    masterVelocity = roundf(velocityControl.value);
    NSLog(@"vel: %d", masterVelocity);
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
         
         int pitch = roundf(attitude.pitch);
         int roll = roundf(attitude.roll);
         int yaw = roundf(attitude.yaw);
         
         dispatch_async(dispatch_get_main_queue(), ^{
             //NSLog(@"%d %d %d", pitch, roll, yaw);
             
             
             
             switch (roll) {
                 //bend high
                 case 1:
                     if(!bent){
                         [self sendPitchBendEvent:127 lsb:127];
                         bent = YES;
                     }
                     break;
                 //bend low
                 case -1:
                     if(!bent){
                         [self sendPitchBendEvent:0 lsb:0];
                         bent = YES;
                     }
                     
                     break;
                     //return normal pitch
                 case 0:
                     if(bent){
                         [self sendPitchBendEvent:64 lsb:64];
                         bent = NO;
                     }
                     break;
             }
             
             switch (pitch) {
                     
                     //move up an octave
                 case 1:
                     if(firstOctave < 5){
                         if(!moving){
                             ++firstOctave;
                             NSLog(@"lowC = %d", firstOctave);
                             [self updateOctaveLabels];
                             lowCMIDIConstant += 12;
                             moving = YES;
                         }
                     }
                     break;
                     //move down an octave
                 case -1:
                     if(firstOctave > 0){
                         if(!moving){
                             --firstOctave;
                             NSLog(@"lowC = %d", firstOctave);
                             [self updateOctaveLabels];
                             lowCMIDIConstant -= 12;
                             moving= YES;
                         }
                     }
                     
                     break;
                     //stop moving
                 case 0:
                     if(moving){
                         moving = NO;
                     }
                     break;
             }
             
             
             
             
         });
     }];
     }


- (void)updateOctaveLabels {
    leftOctave.text = [NSString stringWithFormat:@"C%d", firstOctave];
    rightOctave.text = [NSString stringWithFormat:@"C%d", (firstOctave+1)];
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
    
    
    lowCMIDIConstant = 60;
    firstOctave = 3;
    leftOctave.text = @"C3";
    rightOctave.text = @"C4";
    
    //[self setWantsFullScreenLayout:YES];
	// Do any additional setup after loading the view.
}


- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    masterVelocity = roundf(velocityControl.value);
    NSLog(@"vel: %d", masterVelocity);
    
    [self startDeviceMotion];
    
    
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
