// Copyright (c) Microsoft Corporation.  All rights reserved.

#import <AVFoundation/AVFoundation.h>
#import <CVSInference/CVSObjectDetector.h>
#import "ViewController.h"
#import "BoundingBoxLayer.h"

// controlling the pace of the machine vision analysis
NSTimeInterval lastAnalysis = 0.0;
NSTimeInterval pace = 0.33; // in seconds, classification will not repeat faster than this value

// performance tracking
BOOL trackPerformance = NO; // use "YES" for performance logging
long frameCount = 0;
long framesPerSample = 10;
NSTimeInterval startDate = [NSDate timeIntervalSinceReferenceDate];

@interface ViewController ()<
    AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UIView *boundingBoxView;

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@property (strong, nonatomic) dispatch_queue_t queue;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDevice *captureDevice;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;

@property (strong, nonatomic) CVSObjectDetector *objectDetector;
@property (assign, nonatomic) int unknownCounter; // used to track how many unclassified images in a row
@property (assign, nonatomic) float confidence;

@property (strong, nonatomic) NSArray<UIColor *> *colors;
@property (strong, nonatomic) NSArray<NSString *> *supportedIdentifiers;

@end

@implementation ViewController

#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.captureSession = [[AVCaptureSession alloc] init];
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.previewView.layer addSublayer:self.previewLayer];

    // ObjectDetector configuration
    CVSObjectDetectorConfig *config = [[CVSObjectDetectorConfig alloc] init];
    [config.modelFile setString: [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"CatDog/cvexport.manifest"]];
    [config build];
    self.supportedIdentifiers = config.supportedIdentifiers.values;
    
    // create ObjectDetector
    self.objectDetector = [[CVSObjectDetector alloc] initWithConfig:config];
    
    // color for identifiers
    self.colors = @[
        [UIColor cyanColor],
        [UIColor magentaColor],
        [UIColor orangeColor],
        [UIColor purpleColor],
        [UIColor yellowColor],
        [UIColor brownColor],
        [UIColor redColor],
        [UIColor blueColor],
        [UIColor greenColor],
        [UIColor whiteColor],
    ];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setupCamera];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.previewLayer.frame = self.previewView.bounds;
}

#pragma mark Camera handling

- (void)setupCamera {
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                          mediaType:AVMediaTypeVideo
                                           position:AVCaptureDevicePositionBack];

    AVCaptureDevice *captureDevice = captureDeviceDiscoverySession.devices.lastObject;
    if (captureDevice) {
        self.captureDevice = captureDevice;
        [self beginSession];
    }
}

- (void)beginSession {
    @try {
        self.queue = dispatch_queue_create("videoQueue", DISPATCH_QUEUE_CONCURRENT);

        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        self.videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
        [self.videoOutput setSampleBufferDelegate:self queue:self.queue];
      
        self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
        [self.captureSession addOutput:self.videoOutput];

        AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc]initWithDevice:self.captureDevice error:nil];
        [self.captureSession addInput:input];
        
        [self.captureSession startRunning];
    }
    @catch(NSException *exception) {
        NSLog(@"error connecting to capture device");
    }
}

#pragma mark Video Data Delegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSTimeInterval currentDate = [NSDate timeIntervalSinceReferenceDate];
    
    // control the pace of the machine vision to protect battery life
    if (currentDate - lastAnalysis >= pace) {
        lastAnalysis = currentDate;
    }
    else {
        return; // don't run the classifier more often than we need
    }
    
    // keep track of performance and log the frame rate
    if (trackPerformance) {
        frameCount = frameCount + 1;
        if (frameCount % framesPerSample == 0) {
            NSTimeInterval diff = currentDate - startDate;
            if (diff > 0.0) {
                if (pace > 0.0) {
                    NSLog(@"WARNING: Frame rate of image classification is being limited by \"pace\" setting. Set to 0.0 for fastest possible rate.");
                }
                NSLog(@"%0.2fs per frame (average)", (diff / (double)framesPerSample));
            }
            startDate = currentDate;
        }
    }

    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];

    // ObjectDetector input
    [self.objectDetector.threshold setValue: 0.4f];
    [self.objectDetector.maxReturns setValue: 10];
    [self.objectDetector.image setImage:image];

    // run ObjectDetector
    [self.objectDetector run];

    // ObjectDetector outputs
    VSStringVector *identifiers = self.objectDetector.identifiers;
    VSIntVector *identifierIndexes = self.objectDetector.identifierIndexes;
    VSFloatVector *confidences = self.objectDetector.confidences;
    VSRectVector *boundingBoxes = self.objectDetector.boundingBoxes;

    // display bounding boxes about detected object
    dispatch_sync(dispatch_get_main_queue(), ^{
        // remove previous bounding boxes
        self.boundingBoxView.layer.sublayers = nil;
        
        // create bounding boxes about detected object
        NSInteger cIdentifiers = [identifiers countOfString];
        for (NSInteger i = 0; i < cIdentifiers; i++) {
            const NSString *identifier = [identifiers stringAtIndex:i];
            NSInteger identifierIndex = [identifierIndexes valueAtIndex:i];
            CGFloat confidence = [confidences valueAtIndex:i];
            CGRect rect = [boundingBoxes rectAtIndex:i];

            // convert to rect in screen
            CGPoint p1 = [self.previewLayer pointForCaptureDevicePointOfInterest:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))];
            CGPoint p2 = [self.previewLayer pointForCaptureDevicePointOfInterest:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect))];
            CGRect frame = CGRectMake(fminf(p1.x, p2.x), fminf(p1.y, p2.y), fabs(p2.x - p1.x), fabs(p2.y - p1.y));

            // determine color by index of indentifier
            UIColor *color = self.colors[(identifierIndex % self.colors.count)];
        
            // create bounding box layer and add to view
            BoundingBoxLayer *boundingBoxLayer = [[BoundingBoxLayer alloc] init];
            boundingBoxLayer.frame = frame;
            boundingBoxLayer.label = [NSString stringWithFormat:@"%@ %.1f", identifier, confidence * 100.0f];
            boundingBoxLayer.color = color;
            [self.boundingBoxView.layer addSublayer:boundingBoxLayer];
        }
    });
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);

    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:[self imageOrientationFromDeviceOrientation]];
    CGImageRelease(quartzImage);
    return image;
}

- (UIImageOrientation)imageOrientationFromDeviceOrientation {
    UIDeviceOrientation curDeviceOrientation = [UIDevice currentDevice].orientation;
    UIImageOrientation imageOrientation = UIImageOrientationUp;

    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            imageOrientation = UIImageOrientationLeft;
            break;
        case UIDeviceOrientationLandscapeLeft:
            imageOrientation = UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            imageOrientation = UIImageOrientationDown;
            break;
        case UIDeviceOrientationPortrait:
            imageOrientation = UIImageOrientationRight;
            break;
        default:
            imageOrientation = UIImageOrientationUp;
            break;
    }
    return imageOrientation;
}

@end
