//
//  AppDelegate.h
//  MidiController
//
//  Created by Chris on 14/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>{
    CMMotionManager *motionManager;
    
//    NSNetService *service;
//    uint16_t port;
//    CFSocketRef listeningSocket;
}


@property (strong, nonatomic) UIWindow *window;

@end
