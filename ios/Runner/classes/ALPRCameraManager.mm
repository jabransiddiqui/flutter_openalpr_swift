//
//  CameraManager.m
//  RNOpenAlpr
//
//  Created by Evan Rosenfeld on 2/24/17.
//  Copyright © 2017 CarDash. All rights reserved.
//

#import "ALPRCameraManager.h"
#import <AVFoundation/AVFoundation.h>
#import "PlateScanner.h"
#import "CameraTouchFocusView.h"
#import "RecognizedPlateBorderView.h"
#import <opencv2/imgcodecs/ios.h>

#pragma mark OpenCV -


void rot90(cv::Mat &matImage, int rotflag) {
    // 1=CW, 2=CCW, 3=180
    if (rotflag == 1) {
        // transpose+flip(1)=CW
        transpose(matImage, matImage);
        flip(matImage, matImage, 1);
    } else if (rotflag == 2) {
        // transpose+flip(0)=CCW
        transpose(matImage, matImage);
        flip(matImage, matImage, 0);
    } else if (rotflag == 3){
        // flip(-1)=180
        flip(matImage, matImage, -1);
    }
}

#pragma mark Implementation -

@interface ALPRCameraManager () <AVCapturePhotoCaptureDelegate>  {
    dispatch_queue_t videoDataOutputQueue;
    
}
@property (atomic) BOOL isProcessingFrame;
@property(nonatomic, strong) AVCapturePhotoOutput *avCaptureOutput;
@property(nonatomic, strong) NSHashTable *takePictureParams;
@property(nonatomic, strong) NSDictionary *takePictureOptions;
@property (nonatomic, strong) CameraTouchFocusView *camFocus;
@property (nonatomic, strong) RecognizedPlateBorderView *plateBorder;
@property (atomic) UIDeviceOrientation deviceOrientation;

//@property(nonatomic, strong) RCTPromiseResolveBlock takePictureResolve;
//@property(nonatomic, strong) RCTPromiseRejectBlock takePictureReject;

@end

@implementation ALPRCameraManager{
    BOOL _multipleTouches;
    BOOL _touchToFocus;
    BOOL _showPlateOutline;
    NSString *_plateOutlineColor;
}


+ (BOOL)requiresMainQueueSetup
{
  return YES;
}
/*- (void)viewDidLoad {

    [super viewDidLoad];

    self.session = [AVCaptureSession new];
    #if !(TARGET_IPHONE_SIMULATOR)
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.needsDisplayOnBoundsChange = YES;
    #endif
        
        if(!self.camera){
            self.camera = [[ALPRCamera alloc] initWithManager: self];
        }
}*/
/*- (UIView *)view
{
    self.session = [AVCaptureSession new];
#if !(TARGET_IPHONE_SIMULATOR)
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.needsDisplayOnBoundsChange = YES;
#endif
    
    if(!self.camera){
        self.camera = [[ALPRCamera alloc] initWithManager: self];
    }
    return self.camera;
}*/
- (id)initWithFrame:(CGRect)frame
{
    
    self = [super initWithFrame:frame];
    if (self) {
        self.sessionQueue = dispatch_queue_create("cameraManagerQueue", DISPATCH_QUEUE_SERIAL);
        self.session = [AVCaptureSession new];
    #if !(TARGET_IPHONE_SIMULATOR)
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.needsDisplayOnBoundsChange = YES;
    #endif
        self.previewLayer.frame = frame;
        [self setBackgroundColor:[UIColor blackColor]];
        [self initializeCaptureSessionInput:AVMediaTypeVideo];
        [self startSession];
        
        self.plateBorder = [RecognizedPlateBorderView new];
        
        _multipleTouches = NO;
        _touchToFocus = YES;
        _showPlateOutline = YES;
//        if(!self.camera){
//            self.camera = [[ALPRCamera alloc] initWithManager: self];
//        }
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(stopStreaming:) //note the ":" - should take an NSNotification as parameter
                                                     name:@"stopStreaming"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(startStreaming:) //note the ":" - should take an NSNotification as parameter
                                                     name:@"startStreaming"
                                                   object:nil];
        //[self updatePreviewLayerOrientation];
        [self bringSubviewToFront:self.plateBorder];
    }
    return self;
}

- (void)stopStreaming:(NSNotification *)notification
{
    [self stopSession];
}
- (void)startStreaming:(NSNotification *)notification
{
    [self startSession];
}

/*- (void)initializeALL {
    self.session = [AVCaptureSession new];
#if !(TARGET_IPHONE_SIMULATOR)
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.needsDisplayOnBoundsChange = YES;
#endif
    
    if(!self.camera){
        self.camera = [[ALPRCamera alloc] initWithManager: self];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDidRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
    self->deviceOrientation = [[UIDevice currentDevice] orientation];
    [self updatePreviewLayerOrientation];
    NSLog(@"initializeALL: %s", "test output");
}*/

- (NSDictionary *)constantsToExport
{
    return @{
             @"Aspect": @{
                     @"stretch": @(ALPRCameraAspectStretch),
                     @"fit": @(ALPRCameraAspectFit),
                     @"fill": @(ALPRCameraAspectFill)
                     },
             @"CaptureQuality": @{
                     @"low": @(ALPRCameraCaptureSessionPresetLow),
                     @"AVCaptureSessionPresetLow": @(ALPRCameraCaptureSessionPresetLow),
                     @"medium": @(ALPRCameraCaptureSessionPresetMedium),
                     @"AVCaptureSessionPresetMedium": @(ALPRCameraCaptureSessionPresetMedium),
                     @"high": @(ALPRCameraCaptureSessionPresetHigh),
                     @"AVCaptureSessionPresetHigh": @(ALPRCameraCaptureSessionPresetHigh),
                     @"photo": @(ALPRCameraCaptureSessionPresetPhoto),
                     @"AVCaptureSessionPresetPhoto": @(ALPRCameraCaptureSessionPresetPhoto),
                     @"480p": @(ALPRCameraCaptureSessionPreset480p),
                     @"AVCaptureSessionPreset640x480": @(ALPRCameraCaptureSessionPreset480p),
                     @"720p": @(ALPRCameraCaptureSessionPreset720p),
                     @"AVCaptureSessionPreset1280x720": @(ALPRCameraCaptureSessionPreset720p),
                     @"1080p": @(ALPRCameraCaptureSessionPreset1080p),
                     @"AVCaptureSessionPreset1920x1080": @(ALPRCameraCaptureSessionPreset1080p)
                     },
             @"TorchMode": @{
                     @"off": @(ALPRCameraTorchModeOff),
                     @"on": @(ALPRCameraTorchModeOn),
                     @"auto": @(ALPRCameraTorchModeAuto)
                     },
             @"RotateMode": @{
                     @"off": @false,
                     @"on": @true
                     }
             };
}


- (void) country : (NSString*) country {
    [[PlateScanner sharedInstance] setCountry: @"us"];
}

- (void) quality {
   
    
    [self setCaptureQuality:AVCaptureSessionPresetHigh];
}

- (void) gravity {
   
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
}


//RCT_CUSTOM_VIEW_PROPERTY(torchMode, NSInteger, ALPRCamera) {
//    dispatch_async(self.sessionQueue, ^{
//        NSInteger torchMode = [RCTConvert NSInteger:json];
//        AVCaptureDevice *device = [self.videoCaptureDeviceInput device];
//        NSError *error = nil;
//
//        if (![device hasTorch]) return;
//        if (![device lockForConfiguration:&error]) {
//            NSLog(@"%@", error);
//            return;
//        }
//        [device setTorchMode: (AVCaptureTorchMode)torchMode];
//        [device unlockForConfiguration];
//    });
//}

//RCT_EXPORT_VIEW_PROPERTY(onPlateRecognized, RCTBubblingEventBlock)

- (id)init {
    if ((self = [super init])) {
        self.sessionQueue = dispatch_queue_create("cameraManagerQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


- (void) access {
    __block NSString *mediaType = AVMediaTypeVideo;
    
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
//        resolve(@(granted));
    }];
}

- (void) setting {
    
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
    [self.avCaptureOutput capturePhotoWithSettings:settings delegate:self];
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(nullable NSError *)error
{
    if (!error) {
        NSData *imageData = [photo fileDataRepresentation];
        NSData* compressedImage = [ALPRCameraManager imageWithImage:imageData options:self.takePictureOptions];
        NSString *path = [ALPRCameraManager generatePathInDirectory:[[ALPRCameraManager cacheDirectoryPath] stringByAppendingPathComponent:@"Camera"] withExtension:@".jpg"];
        NSString *uri = [ALPRCameraManager writeImage:compressedImage toPath:path];
//        self.takePictureResolve(uri);
    } else {
//        self.takePictureReject(@"E_IMAGE_CAPTURE_FAILED", @"Image could not be captured", error);
    }
}

+ (NSData *)imageWithImage:(NSData *)imageData options:(NSDictionary *)options {
    UIImage *image = [UIImage imageWithData:imageData];
    
    // Calculate the image size.
    int width = image.size.width, height = image.size.height;
    float quality, scale;
    
    if([options valueForKey:@"width"] != nil) {
        width = [options[@"width"] intValue];
    }
    if([options valueForKey:@"height"] != nil) {
        height = [options[@"height"] intValue];
    }
    
    float widthScale = image.size.width / width;
    float heightScale = image.size.height / height;
    
    if(widthScale > heightScale) {
        scale = heightScale;
    } else {
        scale = widthScale;
    }
    
    if([options valueForKey:@"quality"] != nil) {
        quality = [options[@"quality"] floatValue];
    } else {
        quality = 1.0; // Default quality
    }
    
    UIImage *destImage = [UIImage imageWithCGImage:[image CGImage] scale:scale orientation:UIImageOrientationUp];
    NSData *destData = UIImageJPEGRepresentation(destImage, quality);
    return destData;
}

+ (NSString *)generatePathInDirectory:(NSString *)directory withExtension:(NSString *)extension
{
    NSString *fileName = [[[NSUUID UUID] UUIDString] stringByAppendingString:extension];
    [ALPRCameraManager ensureDirExistsWithPath:directory];
    return [directory stringByAppendingPathComponent:fileName];
}

+ (BOOL)ensureDirExistsWithPath:(NSString *)path
{
    BOOL isDir = NO;
    NSError *error;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    if (!(exists && isDir)) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            return NO;
        }
    }
    return YES;
}

+ (NSString *)writeImage:(NSData *)image toPath:(NSString *)path
{
    [image writeToFile:path atomically:YES];
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    return [fileURL absoluteString];
}

+ (NSString *)cacheDirectoryPath
{
    NSArray *array = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [array objectAtIndex:0];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        if (self.isProcessingFrame) {
            return;
        }
        self.isProcessingFrame = YES;
        
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        // Y_PLANE
        int plane = 0;
        char *planeBaseAddress = (char *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, plane);
        
        size_t width = CVPixelBufferGetWidthOfPlane(imageBuffer, plane);
        size_t height = CVPixelBufferGetHeightOfPlane(imageBuffer, plane);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, plane);
        
        int numChannels = 1;
        
        cv::Mat src = cv::Mat(cvSize((int)width, (int)height), CV_8UC(numChannels), planeBaseAddress, (int)bytesPerRow);
        int rotate = 0;
        if (self.deviceOrientation == UIDeviceOrientationPortrait) {
            rotate = 1;
        } else if (self.deviceOrientation == UIDeviceOrientationLandscapeRight) {
            rotate = 3;
        } else if (self.deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
            rotate = 2;
        }
        rot90(src, rotate);
        
//        NSDate *date = [NSDate date];
        
        [[PlateScanner sharedInstance] scanImage:src onSuccess:^(PlateResult *result) {
            if (result) {
//                NSLog(@"plate: %@", result.plate);
                UIImage* img = MatToUIImage(src);
                
                NSString *encodedString = [UIImagePNGRepresentation(img) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
                
//                NSLog(@"base64: %@", encodedString);
                NSDictionary *myData = @{@"plat_no" : result.plate, @"base64_image": encodedString};
                [[NSNotificationCenter defaultCenter] postNotificationName:@"onStreaming" object:nil userInfo:myData];
//                self.camera.onPlateRecognized(@{
//                    @"confidence": @(result.confidence),
//                    @"plate": result.plate
//                });
            }
            
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
//            NSLog(@"Time: %f", -[date timeIntervalSinceNow]);
            self.isProcessingFrame = NO;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePlateBorder:result orientation:self.deviceOrientation];
            });
            
        } onFailure:^(NSError *err) {
            NSLog(@"Error: %@", err);
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            self.isProcessingFrame = NO;
        }];
    }
}

- (void)startSession {
#if TARGET_IPHONE_SIMULATOR
    return;
#endif
    dispatch_async(self.sessionQueue, ^{
        if (self.presetCamera == AVCaptureDevicePositionUnspecified) {
            self.presetCamera = AVCaptureDevicePositionBack;
        }
        
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        // The algorithm is going to convert to grayscale anyways, so let's use a format that makes it
        // easy to extract
        NSDictionary *videoOutputSettings = @{
            (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        };
        [videoDataOutput setVideoSettings:videoOutputSettings];
        videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        videoDataOutputQueue = dispatch_queue_create("OpenALPR-video-queue", NULL);
        [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
        
        
        if ([self.session canAddOutput:videoDataOutput]) {
            [self.session addOutput:videoDataOutput];
        }
        
        self.avCaptureOutput = [[AVCapturePhotoOutput alloc] init];
        if([self.session canAddOutput:self.avCaptureOutput]) {
            [self.session addOutput:self.avCaptureOutput];
        }
        
        __weak ALPRCameraManager *weakSelf = self;
        [self setRuntimeErrorHandlingObserver:[NSNotificationCenter.defaultCenter addObserverForName:AVCaptureSessionRuntimeErrorNotification object:self.session queue:nil usingBlock:^(NSNotification *note) {
            ALPRCameraManager *strongSelf = weakSelf;
            dispatch_async(strongSelf.sessionQueue, ^{
                // Manually restarting the session since it must have been stopped due to an error.
                [strongSelf.session startRunning];
            });
        }]];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
            [self.session startRunning];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            if(orientation == 0){
                self.deviceOrientation = UIDeviceOrientationUnknown;
                
            }else if(orientation == UIInterfaceOrientationPortrait){
                self.deviceOrientation = UIDeviceOrientationPortrait;
                
            }else if(orientation == UIInterfaceOrientationLandscapeLeft){
                self.deviceOrientation = UIDeviceOrientationLandscapeLeft;       // Device oriented horizontally, home button on the right
               
            }else if(orientation == UIInterfaceOrientationLandscapeRight){
                self.deviceOrientation = UIDeviceOrientationLandscapeRight;     // Device oriented horizontally, home button on the left
            }
            [self updatePreviewLayerOrientation];
            });
        
    });
}

- (void)deviceDidRotate:(NSNotification *)notification
{
    UIDeviceOrientation currentOrientation = [[UIDevice currentDevice] orientation];
    
    // Ignore changes in device orientation if unknown, face up, or face down.
    if (!UIDeviceOrientationIsValidInterfaceOrientation(currentOrientation)) {
        return;
    }
    self.deviceOrientation = currentOrientation;
    [self updatePreviewLayerOrientation];
}

// Function to rotate the previewLayer according to the device's orientation.
- (void)updatePreviewLayerOrientation {
    //Get Preview Layer connection
    AVCaptureConnection *previewLayerConnection = self.previewLayer.connection;
    if ([previewLayerConnection isVideoOrientationSupported]) {
        switch(self.deviceOrientation) {
            case UIDeviceOrientationPortrait:
                [previewLayerConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                [previewLayerConnection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
                break;
            case UIDeviceOrientationLandscapeLeft:
                // Not sure why I need to invert left and right, but this is what is needed for
                // it to function properly. Otherwise it reverses the image.
                [previewLayerConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                break;
            case UIDeviceOrientationLandscapeRight:
                [previewLayerConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
                break;
        }
    }
}

- (void)stopSession {
#if TARGET_IPHONE_SIMULATOR
//    self.camera = nil;
    return;
#endif
    // Make sure that we are on the main thread when we are 
    // ending the session, otherwise we may get an exception:
    // Fatal Exception: NSGenericException
    // *** Collection <CALayerArray: 0x282781230> was mutated while being enumerated.
    // -[ALPRCamera removeFromSuperview]
    [self.previewLayer removeFromSuperlayer];
    [self.session commitConfiguration];
    [self.session stopRunning];
    for(AVCaptureInput *input in self.session.inputs) {
        [self.session removeInput:input];
    }
        
    for(AVCaptureOutput *output in self.session.outputs) {
        [self.session removeOutput:output];
    }
        
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([[UIDevice currentDevice] isGeneratingDeviceOrientationNotifications]) {
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    }
}

- (void)initializeCaptureSessionInput:(NSString *)type {
    dispatch_async(self.sessionQueue, ^{
        [self.session beginConfiguration];
        
        NSError *error = nil;
        AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if (captureDevice == nil) {
            return;
        }
        
        AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
        
        if (error || captureDeviceInput == nil) {
            NSLog(@"%@", error);
            return;
        }
        
//        if (type == AVMediaTypeVideo) {
            [self.session removeInput:self.videoCaptureDeviceInput];
//        }
        
        if ([self.session canAddInput:captureDeviceInput]) {
            [self.session addInput:captureDeviceInput];
//            if (type == AVMediaTypeVideo) {
                self.videoCaptureDeviceInput = captureDeviceInput;
//            }
        }
        
        [self.session commitConfiguration];
    });
}



- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake(.5, .5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *device = [[self videoCaptureDeviceInput] device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
            {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
            {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    });
}

- (void)focusAtThePoint:(CGPoint) atPoint;
{
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        dispatch_async([self sessionQueue], ^{
            AVCaptureDevice *device = [[self videoCaptureDeviceInput] device];
            if([device isFocusPointOfInterestSupported] &&
               [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                CGRect screenRect = [[UIScreen mainScreen] bounds];
                double screenWidth = screenRect.size.width;
                double screenHeight = screenRect.size.height;
                double focus_x = atPoint.x/screenWidth;
                double focus_y = atPoint.y/screenHeight;
                if([device lockForConfiguration:nil]) {
                    [device setFocusPointOfInterest:CGPointMake(focus_x,focus_y)];
                    [device setFocusMode:AVCaptureFocusModeAutoFocus];
                    if ([device isExposureModeSupported:AVCaptureExposureModeAutoExpose]){
                        [device setExposureMode:AVCaptureExposureModeAutoExpose];
                    }
                    [device unlockForConfiguration];
                }
            }
        });
    }
}

- (void)zoom:(CGFloat)velocity reactTag:(NSNumber *)reactTag{
    if (isnan(velocity)) {
        return;
    }
    const CGFloat pinchVelocityDividerFactor = 20.0f; // TODO: calibrate or make this component's property
    NSError *error = nil;
    AVCaptureDevice *device = [[self videoCaptureDeviceInput] device];
    if ([device lockForConfiguration:&error]) {
        CGFloat zoomFactor = device.videoZoomFactor + atan(velocity / pinchVelocityDividerFactor);
        if (zoomFactor > device.activeFormat.videoMaxZoomFactor) {
            zoomFactor = device.activeFormat.videoMaxZoomFactor;
        } else if (zoomFactor < 1) {
            zoomFactor = 1.0f;
        }

        NSDictionary *event = @{
          @"target": reactTag,
          @"zoomFactor": [NSNumber numberWithDouble:zoomFactor],
          @"velocity": [NSNumber numberWithDouble:velocity]
        };

//        [self.bridge.eventDispatcher sendAppEventWithName:@"zoomChanged" body:event];

        device.videoZoomFactor = zoomFactor;
        [device unlockForConfiguration];
    } else {
        NSLog(@"error: %@", error);
    }
}

- (void)setCaptureQuality:(NSString *)quality
{
#if !(TARGET_IPHONE_SIMULATOR)
    if (quality) {
        [self.session beginConfiguration];
        if ([self.session canSetSessionPreset:quality]) {
            self.session.sessionPreset = quality;
        }
        [self.session commitConfiguration];
    }
#endif
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Update the touch state.
    if ([[event touchesForView:self] count] > 1) {
        _multipleTouches = YES;
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_touchToFocus) return;
    
    BOOL allTouchesEnded = ([touches count] == [[event touchesForView:self] count]);
    
    // Do not conflict with zooming and etc.
    if (allTouchesEnded && !_multipleTouches) {
        UITouch *touch = [[event allTouches] anyObject];
        CGPoint touchPoint = [touch locationInView:touch.view];
        // Focus camera on this point
        [self focusAtThePoint:touchPoint];
        
        if (self.camFocus)
        {
            [self.camFocus removeFromSuperview];
        }
        NSDictionary *event = @{
//          @"target": self.reactTag,
          @"touchPoint": @{
            @"x": [NSNumber numberWithDouble:touchPoint.x],
            @"y": [NSNumber numberWithDouble:touchPoint.y]
          }
        };
//        [self.bridge.eventDispatcher sendAppEventWithName:@"focusChanged" body:event];

        // Show animated rectangle on the touched area
        if (_touchToFocus) {
            self.camFocus = [[CameraTouchFocusView alloc]initWithFrame:CGRectMake(touchPoint.x-40, touchPoint.y-40, 80, 80)];
            [self.camFocus setBackgroundColor:[UIColor clearColor]];
            [self addSubview:self.camFocus];
            [self.camFocus setNeedsDisplay];
            
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:1.0];
            [self.camFocus setAlpha:0.0];
            [UIView commitAnimations];
        }
    }
    
    if (allTouchesEnded) {
        _multipleTouches = NO;
    }

}

- (void)updatePlateBorder:(PlateResult *)result orientation:(UIDeviceOrientation)orientation {
    if (!_showPlateOutline) return;
    if (!UIDeviceOrientationIsValidInterfaceOrientation(orientation)) return;
    if (!result) {
        [UIView animateWithDuration:0.2f animations:^{
            self.plateBorder.alpha = 0;
        }];
        return;
    }
    NSArray *points = result.points;
    NSMutableArray *newPoints = [NSMutableArray array];
    for (int i = 0; i < points.count; i++) {
        CGPoint pt = [[points objectAtIndex:i] CGPointValue];
        CGPoint newPt;
        
        // To undertand what is happening here, draw a rectangle representing the screen.
        // Make a small circle where the home button is located and mark any point (x,y).
        // The x-axis is cols, the y-axis is rows. Now, rotate the picture so that the home
        // button is on the right side. We want to transform our (x,y) into a new coordinate
        // system where the top-left is (0,0) and bottom right is (1,1)
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                newPt = CGPointMake(pt.y / result.rows, (result.cols - pt.x) / result.cols);
                break;
            case UIDeviceOrientationLandscapeLeft:
                newPt = CGPointMake(pt.x / result.cols, pt.y / result.rows);
                break;
            case UIDeviceOrientationLandscapeRight:
                newPt = CGPointMake((result.cols - pt.x) / result.cols, (result.rows - pt.y) / result.rows);
                break;
            default:
                break;
        }
        [newPoints addObject:[NSValue valueWithCGPoint:[self.previewLayer pointForCaptureDevicePointOfInterest:newPt]]];
    }
    [self layoutSubviews];
    [UIView animateWithDuration:0.2f animations:^{
        self.plateBorder.alpha = 1;
        [self layoutSubviews];
        [self.plateBorder updateCorners:newPoints];
        [self layoutSubviews];
    }];
    [self layoutSubviews];
}
- (void)layoutSubviews
{
    [super layoutSubviews];
    self.previewLayer.frame = self.bounds;
    self.plateBorder.frame = self.bounds;
    [self setBackgroundColor:[UIColor blackColor]];
    [self.layer insertSublayer:self.previewLayer atIndex:0];
    if (_showPlateOutline) {
        [self addSubview:self.plateBorder];
    }
}


@end
