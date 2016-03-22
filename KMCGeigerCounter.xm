//
//  KMCGeigerCounter.m
//  KMCGeigerCounter
//
//  Created by Kevin Conner on 10/21/14.
//  Copyright (c) 2014 Kevin Conner. All rights reserved.
//

#import "KMCGeigerCounter.h"
#import <SpriteKit/SpriteKit.h>

// I'd prefer "static NSInteger const kHardwareFramesPerSecond = 60;", but
// that doesn't work for all options of the "C Language Dialect" build setting.
// https://github.com/kconner/KMCGeigerCounter/issues/3
#define kHardwareFramesPerSecond 60

static NSTimeInterval const kNormalFrameDuration = 1.0 / kHardwareFramesPerSecond;

@interface KMCGeigerCounter () {
    CFTimeInterval _lastSecondOfFrameTimes[kHardwareFramesPerSecond];
}

@property (nonatomic, readwrite, getter = isRunning) BOOL running;

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UILabel *meterLabel;
@property (nonatomic, retain) UIColor *meterPerfectColor;
@property (nonatomic, retain) UIColor *meterGoodColor;
@property (nonatomic, retain) UIColor *meterBadColor;

@property (nonatomic, retain) SKView *sceneView;

@property (nonatomic, retain) CADisplayLink *displayLink;

@property (nonatomic, assign) NSInteger frameNumber;

@end

@implementation KMCGeigerCounter

#pragma mark - Helpers

- (CFTimeInterval)lastFrameTime
{
    return _lastSecondOfFrameTimes[self.frameNumber % kHardwareFramesPerSecond];
}

- (void)recordFrameTime:(CFTimeInterval)frameTime
{
    ++self.frameNumber;
    _lastSecondOfFrameTimes[self.frameNumber % kHardwareFramesPerSecond] = frameTime;
}

- (void)clearLastSecondOfFrameTimes
{
    CFTimeInterval initialFrameTime = CACurrentMediaTime();
    for (NSInteger i = 0; i < kHardwareFramesPerSecond; ++i) {
        _lastSecondOfFrameTimes[i] = initialFrameTime;
    }
    self.frameNumber = 0;
}

- (void)updateMeterLabel
{
    NSInteger drawnFrameCount = self.drawnFrameCountInLastSecond;

    if (drawnFrameCount < 0) {
        self.meterLabel.backgroundColor = [UIColor grayColor];
    }
    else if (drawnFrameCount > 50) {
        self.meterLabel.backgroundColor = self.meterPerfectColor;
    }
    else if (drawnFrameCount > 30) {
        self.meterLabel.backgroundColor = self.meterGoodColor;
    }
    else {
        self.meterLabel.backgroundColor = self.meterBadColor;
    }
    self.meterLabel.text = [NSString stringWithFormat:@"%ld", (long)drawnFrameCount];
}

- (void)displayLinkWillDraw:(CADisplayLink *)displayLink
{
    CFTimeInterval currentFrameTime = displayLink.timestamp;

    [self recordFrameTime:currentFrameTime];

    [self updateMeterLabel];
}

#pragma mark -

- (void)start
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkWillDraw:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self clearLastSecondOfFrameTimes];

    // Low framerates can be caused by CPU activity on the main thread or by long compositing time in (I suppose)
    // the graphics driver. If compositing time is the problem, and it doesn't require on any main thread activity
    // between frames, then the framerate can drop without CADisplayLink detecting it.
    // Therefore, put an empty 1pt x 1pt SKView in the window. It shouldn't interfere with the framerate, but
    // should cause the CADisplayLink callbacks to match the timing of drawing.
    SKScene *scene = [[[SKScene alloc] init] autorelease];
    self.sceneView = [[[SKView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1.0, 1.0)] autorelease];
    [self.sceneView presentScene:scene];

    [[UIApplication sharedApplication].keyWindow addSubview:self.sceneView];
}

- (void)stop
{
    [self.sceneView removeFromSuperview];
    self.sceneView = nil;

    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)setRunning:(BOOL)running
{
    if (_running != running) {
        if (running) {
            [self start];
        } else {
            [self stop];
        }

        _running = running;
    }
}

#pragma mark -

- (void)applicationDidBecomeActive
{
    self.running = self.enabled;
}

- (void)applicationWillResignActive
{
    self.running = NO;
}

#pragma mark -

- (void)enable
{
    self.window = [[[UIWindow alloc] initWithFrame:[UIApplication sharedApplication].statusBarFrame] autorelease];
    self.window.windowLevel = UIWindowLevelStatusBar + 100.0;
    self.window.userInteractionEnabled = NO;
    
    UIViewController *rootViewController = [[[UIViewController alloc] init] autorelease];
    rootViewController.view.frame = self.window.bounds;
    self.window.rootViewController = rootViewController;

    CGFloat const kMeterWidth = 65.0;
    CGFloat xOrigin = 0.0;
    switch (self.position) {
        case KMCGeigerCounterPositionLeft:
            xOrigin = 0.0;
            break;
        case KMCGeigerCounterPositionMiddle:
            xOrigin = (self.window.bounds.size.width - kMeterWidth) / 2.0;
            break;
        case KMCGeigerCounterPositionRight:
            xOrigin = (self.window.bounds.size.width - kMeterWidth);
            break;
    }
    self.meterLabel = [[[UILabel alloc] initWithFrame:CGRectMake(xOrigin, 0.0,
                                                                kMeterWidth, self.window.bounds.size.height)] autorelease];
    self.meterLabel.font = [UIFont boldSystemFontOfSize:12.0];
    self.meterLabel.backgroundColor = [UIColor grayColor];
    self.meterLabel.textColor = [UIColor whiteColor];
    self.meterLabel.textAlignment = NSTextAlignmentCenter;
    [self.window.rootViewController.view addSubview:self.meterLabel];
    self.window.hidden = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        self.running = YES;
    }
}

- (void)disable
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.running = NO;

    self.meterLabel = nil;
    self.window = nil;
}

#pragma mark - Init/dealloc

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.position = KMCGeigerCounterPositionMiddle;

        self.meterPerfectColor = [UIColor colorWithRed:0.259 green:0.396 blue:0.000 alpha:1.000];
        self.meterGoodColor = [UIColor colorWithRed:0.396 green:0.361 blue:0.000 alpha:1.000];
        self.meterBadColor = [UIColor colorWithRed:0.498 green:0.035 blue:0.043 alpha:1.000];
    }
    return self;
}

- (void)dealloc
{
    [_displayLink invalidate];

    self.displayLink = nil;
    self.sceneView = nil;
    self.meterBadColor = nil;
    self.meterGoodColor = nil;
    self.meterPerfectColor = nil;
    self.meterLabel = nil;
    self.window = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

#pragma mark - Public interface

+ (instancetype)sharedGeigerCounter
{
    static KMCGeigerCounter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [KMCGeigerCounter new];
    });
    return instance;
}

- (void)setEnabled:(BOOL)enabled
{
    if (_enabled != enabled) {
        if (enabled) {
            [self enable];
        } else {
            [self disable];
        }

        _enabled = enabled;
    }
}

- (NSInteger)droppedFrameCountInLastSecond
{
    NSInteger droppedFrameCount = 0;

    CFTimeInterval lastFrameTime = CACurrentMediaTime() - kNormalFrameDuration;
    for (NSInteger i = 0; i < kHardwareFramesPerSecond; ++i) {
        if (1.0 <= lastFrameTime - _lastSecondOfFrameTimes[i]) {
            ++droppedFrameCount;
        }
    }

    return droppedFrameCount;
}

- (NSInteger)drawnFrameCountInLastSecond
{
    if (!self.running || self.frameNumber < kHardwareFramesPerSecond) {
        return -1;
    }

    return kHardwareFramesPerSecond - self.droppedFrameCountInLastSecond;
}

@end
