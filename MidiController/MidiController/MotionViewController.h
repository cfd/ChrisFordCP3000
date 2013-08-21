//
//  GyroViewController.h
//  MidiController
//
//  Created by Chris on 18/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

@interface  MotionViewController : UIViewController{

    IBOutlet UILabel* accX;
    IBOutlet UILabel* accY;
    IBOutlet UILabel* accZ;
    
    
    IBOutlet UILabel* gyroX;
    IBOutlet UILabel* gyroY;
    IBOutlet UILabel* gyroZ;
}



@end
