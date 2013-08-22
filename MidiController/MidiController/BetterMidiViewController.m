//
//  BetterMidiViewController.m
//  MidiController
//
//  Created by Chris on 22/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "BetterMidiViewController.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <mach/mach_time.h>

@interface BetterMidiViewController ()

@end

static BetterMidiViewController* instance = nil;


@implementation BetterMidiViewController


static void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error); if (isprint(errorString[1]) && isprint(errorString[2]) &&
                                                                    isprint(errorString[3]) && isprint(errorString[4])) { errorString[0] = errorString[5] = '\''; errorString[6] = '\0';
    } else {
        
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
        fprintf(stderr, "Error: %s (%s)\n", operation, errorString); exit(1);
    }
}


-(void) configurePort {
    
    session = [MIDINetworkSession defaultSession]; if (session) {
        NSLog (@"Got MIDI session");
        //[session addConnection:connection]; session.enabled = YES;
        destinationEndpoint = [session destinationEndpoint];
        MIDIClientRef client = NULL;
        MIDIPortRef outport = NULL;
        CheckError (MIDIClientCreate(CFSTR("MyMIDIWifi Client"),
                                     NULL, NULL, &client), "Couldn't create MIDI client"); CheckError (MIDIOutputPortCreate(client,
                                                                                                                            CFSTR("MyMIDIWifi Output port"),
                                                                                                                            &outport), "Couldn't create output port");
        outputPort = outport;
        NSLog (@"Got output port");
    }
}

-(void) sendStatus:(Byte)status data1:(Byte)data1 data2:(Byte)data2 {
    MIDIPacketList packetList;
    packetList.numPackets = 1;
    packetList.packet[0].length = 3;
    packetList.packet[0].data[0] = status;
    packetList.packet[0].data[1] = data1;
    packetList.packet[0].data[2] = data2;
    packetList.packet[0].timeStamp = 0;
    CheckError (MIDISend(outputPort, destinationEndpoint, &packetList), "Couldn't send MIDI packet list");
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
    NSLog(@"heyyy");
    NSNetService *remoteService = service;
    remoteService.delegate = self;
    [remoteService resolveWithTimeout:10];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    NSLog(@"HELLO");
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
            
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", nil];
            
            NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
            [center postNotificationName:@"DiscoveredContact"
                                  object:self
                                userInfo:userInfo];
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

- (void) onChannel: (UInt8) chan
         startNote: (UInt8) note
      withVelocity: (UInt8) velocity {
    
    if (chan < 16 && note < 128 && velocity < 128) {
        
        Byte rawBuffer[1024];
        MIDIPacketList* packetBuffer = (MIDIPacketList*) rawBuffer;
        
        Byte midiBuffer[3];
        midiBuffer[0] = 144 + chan-1;
        midiBuffer[1] = note;
        midiBuffer[2] = velocity;
        
        MIDITimeStamp timestamp = mach_absolute_time();
        
        MIDIPacket* curr = MIDIPacketListInit(packetBuffer);
        curr = MIDIPacketListAdd(packetBuffer, sizeof(rawBuffer), curr, timestamp, 3, midiBuffer);
        
        NSLog(@"MIDIsend %d %d %d",chan, note, velocity);
        MIDISend(outputPort, [[MIDINetworkSession defaultSession] destinationEndpoint], packetBuffer);
    }
}

- (void) onChannel: (UInt8) chan
          stopNote: (UInt8) note
      withVelocity: (UInt8) velocity {
    
    if (chan < 16 && note < 128 && velocity < 128) {
        
        Byte rawBuffer[1024];
        MIDIPacketList* packetBuffer = (MIDIPacketList*) rawBuffer;
        
        Byte midiBuffer[3];
        midiBuffer[0] = 128 + chan-1;
        midiBuffer[1] = note;
        midiBuffer[2] = velocity;
        
        MIDITimeStamp timestamp = mach_absolute_time();
        
        MIDIPacket* curr = MIDIPacketListInit(packetBuffer);
        curr = MIDIPacketListAdd(packetBuffer, sizeof(rawBuffer), curr, timestamp, 3, midiBuffer);
        
        NSLog(@"MIDIsend %d %d %d",chan, note, velocity);
        MIDISend(outputPort, [[MIDINetworkSession defaultSession] destinationEndpoint], packetBuffer);
    }
}

- (IBAction)handleKeyDown:(id)sender{
    printf("midiNumberDown: %d", [sender tag]);
    [self onChannel:11 startNote:[sender tag] withVelocity:127];
    //NSInteger note = [sender tag];
    //[self sendNoteOnEvent:(Byte) note velocity:127];
    
    
}
- (IBAction)handleKeyUp:(id)sender{
    printf("midiNumberUp: %d", [sender tag]);
    [self onChannel:11 stopNote:[sender tag] withVelocity:127];
    //NSInteger note = [sender tag];
    //[self sendNoteOffEvent:(Byte) note velocity:127];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configurePort];
    [self search];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
