// Copyright (c) Microsoft Corporation.  All rights reserved.

#import <AVFoundation/AVFoundation.h>
#import <CVSInference/CVSClassifier.h>
#import "ViewController.h"
#import "BubbleLayer.h"

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
@property (weak, nonatomic) IBOutlet UIStackView *stackView;
@property (weak, nonatomic) IBOutlet UIView *lowerView;

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong, nonatomic) BubbleLayer *bubbleLayer;

@property (strong, nonatomic) dispatch_queue_t queue;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDevice *captureDevice;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;

@property (strong, nonatomic) CVSClassifier *classifier;
@property (assign, nonatomic) int unknownCounter; // used to track how many unclassified images in a row
@property (assign, nonatomic) float confidence;

@end

@implementation ViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _bubbleLayer = [[BubbleLayer alloc] initWithString:@""];
        _unknownCounter = 0;
        _confidence = 0.7;
    }
    return self;
}

#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.captureSession = [[AVCaptureSession alloc] init];
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.previewView.layer addSublayer:self.previewLayer];

    // create skill configuration
    CVSClassifierConfig *config = [[CVSClassifierConfig alloc] init];
    [config.modelFile setString: [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Fruit/cvexport.manifest"]];
    [config build];

    // create skill instance
    self.classifier = [[CVSClassifier alloc] initWithConfig:config];
}

- (void)viewDidAppear:(BOOL)animated {
    self.bubbleLayer.opacity = 0.0;
    self.bubbleLayer.position = CGPointMake(self.view.frame.size.width / 2.0,
                                            self.lowerView.frame.size.height / 2);
    [self.lowerView.layer addSublayer:self.bubbleLayer];
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

    [self.classifier.threshold setValue: 0.f]; // want to see even low confidence returns
    [self.classifier.maxReturns setValue: 1]; // this model is just a boolean is/is not
    [self.classifier.image setImage:[self imageFromSampleBuffer:sampleBuffer]];
    [self.classifier run];
    const NSString *bestIdentifier = [self.classifier.identifiers stringAtIndex:0];
    float_t bestConfidence = [self.classifier.confidences valueAtIndex:0];

    // Use results to update user interface (includes basic filtering)
    NSLog(@"%@: %f", bestIdentifier, bestConfidence);
    if ([bestIdentifier hasPrefix:@"Unknown"] || bestConfidence < self.confidence) {
        if (self.unknownCounter < 3) { // a bit of a low-pass filter to avoid flickering
            self.unknownCounter += 1;
        }
        else {
            self.unknownCounter = 0;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.bubbleLayer.string = nil;
            });
          }
    }
    else {
        self.unknownCounter = 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            // Trimming labels because they sometimes have unexpected line endings which show up in the GUI
            self.bubbleLayer.string = [bestIdentifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        });
    }
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
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
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
