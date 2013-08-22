//
//  SetupController.m
//  iPerform
//
//  Created by Jason Holdsworth on 11/04/11.
//  Copyright 2011 NerdJam. All rights reserved.
//

#import "MIDINetworkDiscovery.h"

static MIDINetworkDiscovery* instance = nil;

static MIDINetworkSession* session = nil;

@implementation MIDINetworkDiscovery

#pragma mark - NSNetServiceBrowserDelegate methods

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    //Logger(@"browser is searching...");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
    @synchronized (session) {
        //Logger(@"found domain: %@", domainString);
        //[browser release];
        // NOTE: you must create a new browser each time you search!
        if (!moreComing) {
            browser = [NSNetServiceBrowser new];
            browser.delegate = self;
            [browser searchForServicesOfType:MIDINetworkBonjourServiceType inDomain:domainString];
        }
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    @synchronized (session) {
        //[aNetService retain];
        //Logger(@"browser found service %@", aNetService.name);
        //Logger(@"more? %s",moreComing ? "yes" : "no");
        aNetService.delegate = self;
        [aNetService resolveWithTimeout:5];
    }
}

#pragma mark - NSNetServiceDelegate methods

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    @synchronized (session) {
        NSString *name = service.name;
        //    Logger(@"resolved service address for %@", name);
        //    NSString* hostName = service.hostName;
        
        //        MIDINetworkSession* session = [MIDINetworkSession defaultSession];
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
        //[set release];
        
        // NOTE: dont add contact to the MIDI network itself! :)
        if (isNewContact && [name caseInsensitiveCompare:session.networkName] != NSOrderedSame) {
            
            //Logger(@"added contact: %@", name);
            [session addContact:contact];
            
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", nil];
            
            NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
            [center postNotificationName:@"DiscoveredContact"
                                  object:self
                                userInfo:userInfo];
        }
        //[service release];
    }
}

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
    @synchronized (session) {
        //Logger(@"did not resolve net service %@ %@", service, errorDict);
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center postNotificationName:@"DidNotResolve"
                              object:self];
        //[service release];
    }
}

#pragma mark - general methods

- (void) clearContacts {
    //    MIDINetworkSession* session = [MIDINetworkSession defaultSession];
    //Logger(@"clearing contacts...");
    
    @synchronized (session) {
        NSSet* set = [[NSSet alloc] initWithSet:session.contacts];
        for (MIDINetworkHost* host in set)
        {
            //Logger(@"removed contact %@", [host name]);
            [session removeContact:host];
        }
        //[set release];
    }
}

- (void) search {
    [[MIDINetworkDiscovery getInstance] clearContacts];
    //[browser release];
    browser = [NSNetServiceBrowser new];
    browser.delegate = instance;
    [browser searchForRegistrationDomains];
}


#pragma mark - SINGLETON methods

+ (MIDINetworkDiscovery*)getInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [MIDINetworkDiscovery new];
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

@end
