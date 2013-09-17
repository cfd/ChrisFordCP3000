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
    //    __block float stepMoveFactor = 15;
    
    [self.motionManager startDeviceMotionUpdatesToQueue:[[NSOperationQueue alloc]init] withHandler:^(CMDeviceMotion *data,NSError *error)
     {
         CMAttitude *attitude = data.attitude;
         
         dispatch_async(dispatch_get_main_queue(), ^{
             int pitch = roundf(attitude.pitch);
             int roll = roundf(attitude.roll);
             int yaw = roundf(attitude.yaw);
             //NSLog(@"%d   %d   %d", pitch, roll, yaw);
             
             
             [self round:attitude.yaw];
             
         });
     }];
}

-(void)round:(float)yaw{
    NSLog(@"%f", yaw);
    int noteRefNumber=0;
    if(yaw >= -1.002 && yaw > -0.835){
        noteRefNumber = 1;
    }
    else if(yaw >= -1.002 && yaw < -0.835){
        noteRefNumber = 2;
    }
    else if(yaw >= -0.835 && yaw < -0.668){
        noteRefNumber = 3;
    }
    else if(yaw >= -0.668 && yaw < -0.501){
        noteRefNumber = 4;
    }
    else if(yaw >= -0.501 && yaw < -0.334){
        noteRefNumber = 5;
    }
    else if(yaw >= -0.334 && yaw < -0.167){
        noteRefNumber = 6;
    }
    else if(yaw >= -0.167 && yaw < 0){
        noteRefNumber = 7;
    }
    else if(yaw >= 0 && yaw < 0.167){
        noteRefNumber = 8;
    }
    else if(yaw >= 0.167 && yaw < 0.334){
        noteRefNumber = 9;
    }
    else if(yaw >= 0.334 && yaw < 0.501){
        noteRefNumber = 10;
    }
    else if(yaw >= 0.501 && yaw < 0.668){
        noteRefNumber = 11;
    }
    else if(yaw >= 0.668 && yaw < 0.835){
        noteRefNumber = 12;
    }
    else if(yaw >= 0.835 && yaw < 1.002){
        noteRefNumber = 13;
    }
    
    
    NSLog(@"%d", noteRefNumber);
}

-(void)changePointedNoteWithCurrent:(UILabel*)note{
    aStatusLabel.backgroundColor = nil;
    bStatusLabel.backgroundColor = nil;
    cStatusLabel.backgroundColor = nil;
    dStatusLabel.backgroundColor = nil;
    eStatusLabel.backgroundColor = nil;
    fStatusLabel.backgroundColor = nil;
    gStatusLabel.backgroundColor = nil;
    
    note.backgroundColor = red;
    
}




- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startDeviceMotion];
    green = [UIColor colorWithRed:0 green:255 blue:0 alpha:1];
    white = [UIColor colorWithRed:255 green:255 blue:255 alpha:1];
    red = [UIColor colorWithRed:255 green:0 blue:0 alpha:1];
    
    NSLog(@"Motion updates began");
    
    velocity = roundf(velocitySlider.value);
    
}



- (IBAction)sliderValueChanged:(id)sender{
    velocity = roundf(velocitySlider.value);
    NSLog(@"value is now %d", velocity);
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
