//
//  MidiViewController.h
//  MidiController
//
//  Created by Chris on 19/08/13.
//  Copyright (c) 2013 Chris. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreMIDI/CoreMIDI.h>



@interface MidiViewController : UIViewController{

}

- (IBAction)handleKeyDown:(id)sender;
- (IBAction)handleKeyUp:(id)sender;
@end

