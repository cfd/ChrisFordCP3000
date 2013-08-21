//
//  GyroViewController.m
//  MidiController
//
//  Created by Chris on 18/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import "MotionViewController.h"

@interface MotionViewController ()

@end

@implementation MotionViewController


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
            printf("AccX: %f\nAccY: %f\nAccZ: %f\r\n", data.acceleration.x, data.acceleration.y, data.acceleration.z);
            accX.text = [NSString stringWithFormat:@"X: %f", data.acceleration.x];
            accY.text = [NSString stringWithFormat:@"Y: %f", data.acceleration.y];
            accZ.text = [NSString stringWithFormat:@"Z: %f", data.acceleration.z];
                    });
    }];
}


- (void)startGyroscope{
    //    __block float stepMoveFactor = 15;
    
    [self.motionManager startGyroUpdatesToQueue:[[NSOperationQueue alloc]init] withHandler:^(CMGyroData *data,NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
             printf("GyroX: %f\nGyroY: %f\nGyroZ: %f\r\n", data.rotationRate.x, data.rotationRate.y, data.rotationRate.z);
             gyroX.text = [NSString stringWithFormat:@"X: %f", data.rotationRate.x];
             gyroY.text = [NSString stringWithFormat:@"Y: %f", data.rotationRate.y];
             gyroZ.text = [NSString stringWithFormat:@"Z: %f", data.rotationRate.z];
         });
     }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
}

- (void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startAccelerometer];
    [self startGyroscope];
}

- (void) viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.motionManager stopAccelerometerUpdates];
    [self.motionManager stopGyroUpdates];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
