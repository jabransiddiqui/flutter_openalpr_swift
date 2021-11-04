//
//  RCTCamera.h
//  RNOpenAlpr
//
//  Created by Evan Rosenfeld on 2/24/17.
//  Copyright © 2017 CarDash. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVFoundation.h>

#import "PlateResult.h"

@class ALPRCameraManager;

@interface ALPRCamera : UIView

//@property (nonatomic, copy) RCTBubblingEventBlock onPlateRecognized;

- (id)initWithManager:(ALPRCameraManager*)manager;

- (void) updatePlateBorder:(PlateResult *)result orientation:(UIDeviceOrientation)orientation;
@end
