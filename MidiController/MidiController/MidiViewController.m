//
//  MidiViewController.m
//  MidiController
//
//  Created by Chris on 19/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//



#import "MidiViewController.h"

@interface MidiViewController ()

- (void) connectToHost;
- (void) sendStatus:(Byte)status data1:(Byte)data1 data2:(Byte)data2;
- (void) sendNoteOnEvent:(Byte) note velocity:(Byte)velocity;
- (void) sendNoteOffEvent:(Byte)key velocity:(Byte)velocity;

@property (assign) MIDINetworkSession *midiSession;
@property (assign) MIDIEndpointRef destinationEndpoint;
@property (assign) MIDIPortRef outputPort;



@end

@implementation MidiViewController
@synthesize midiSession;
@synthesize destinationEndpoint;
@synthesize outputPort;

- (IBAction)handleKeyDown:(id)sender{
    printf("midiNumberDown: %d", [sender tag]);
    NSInteger note = [sender tag];
    [self sendNoteOnEvent:(Byte) note velocity:127];
    
    
}
- (IBAction)handleKeyUp:(id)sender{
    printf("midiNumberUp: %d", [sender tag]);
    NSInteger note = [sender tag];
    [self sendNoteOffEvent:(Byte) note velocity:127];
}

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

-(void) connectToHost {
    MIDINetworkHost *host = [MIDINetworkHost hostWithName:@"MyMIDIWifi"
                                                  address:@"172.20.10.2" port:5004];
    if(!host) return;
    
    MIDINetworkConnection *connection =
    [MIDINetworkConnection connectionWithHost:host]; if(!connection)
        return;
    
    self.midiSession = [MIDINetworkSession defaultSession]; if (self.midiSession) {
        NSLog (@"Got MIDI session");
        [self.midiSession addConnection:connection]; self.midiSession.enabled = YES;
        self.destinationEndpoint = [self.midiSession destinationEndpoint];
        MIDIClientRef client = NULL;
        MIDIPortRef outport = NULL;
        CheckError (MIDIClientCreate(CFSTR("MyMIDIWifi Client"),
                                     NULL, NULL, &client), "Couldn't create MIDI client"); CheckError (MIDIOutputPortCreate(client,
                                                                                     CFSTR("MyMIDIWifi Output port"),
                                                                                     &outport), "Couldn't create output port");
        self.outputPort = outport;
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
    CheckError (MIDISend(self.outputPort, self.destinationEndpoint, &packetList), "Couldn't send MIDI packet list");
}

-(void) sendNoteOnEvent:(Byte)key velocity:(Byte)velocity {
    [self sendStatus:0x90 data1:key & 0x7F data2:velocity & 0x7F];
}
-(void) sendNoteOffEvent:(Byte)key velocity:(Byte)velocity {
    [self sendStatus:0x80 data1:key & 0x7F data2:velocity & 0x7F];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self connectToHost];
}








@end
