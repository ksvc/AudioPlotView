//
//  KSYAudioDisplayLink.m
//  EditDemo
//
//  Created by sunyazhou on 2017/6/15.
//  Copyright © 2017年 Kingsoft, Inc. All rights reserved.
//

#import "KSYAudioDisplayLink.h"

//------------------------------------------------------------------------------
#pragma mark - CVDisplayLink Callback (Declaration)
//------------------------------------------------------------------------------

#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
static CVReturn KSYAudioDisplayLinkCallback(CVDisplayLinkRef displayLinkRef,
                                           const CVTimeStamp *now,
                                           const CVTimeStamp *outputTime,
                                           CVOptionFlags flagsIn,
                                           CVOptionFlags *flagsOut,
                                           void   *displayLinkContext);
#endif

//------------------------------------------------------------------------------
#pragma mark - KSYAudioDisplayLink (Interface Extension)
//------------------------------------------------------------------------------

@interface KSYAudioDisplayLink ()
#if TARGET_OS_IPHONE
@property (nonatomic, strong) CADisplayLink *displayLink;
#elif TARGET_OS_MAC
@property (nonatomic, assign) CVDisplayLinkRef displayLink;
#endif
@property (nonatomic, assign) BOOL stopped;
@end

//------------------------------------------------------------------------------
#pragma mark - KSYAudioDisplayLink (Implementation)
//------------------------------------------------------------------------------

@implementation KSYAudioDisplayLink

//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)dealloc
{
#if TARGET_OS_IPHONE
    [self.displayLink invalidate];
#elif TARGET_OS_MAC
    CVDisplayLinkStop(self.displayLink);
    CVDisplayLinkRelease(self.displayLink);
    self.displayLink = nil;
#endif
}

//------------------------------------------------------------------------------
#pragma mark - Class Initialization
//------------------------------------------------------------------------------

+ (instancetype)displayLinkWithDelegate:(id<KSYAudioDisplayLinkDelegate>)delegate
{
    KSYAudioDisplayLink *displayLink = [[self alloc] init];
    displayLink.delegate = delegate;
    return displayLink;
}

//------------------------------------------------------------------------------
#pragma mark - Initialization
//------------------------------------------------------------------------------

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        [self setup];
    }
    return self;
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)setup
{
    self.stopped = YES;
#if TARGET_OS_IPHONE
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
#elif TARGET_OS_MAC
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(self.displayLink,
                                   KSYAudioDisplayLinkCallback,
                                   (__bridge void *)(self));
    CVDisplayLinkStart(self.displayLink);
#endif
}

//------------------------------------------------------------------------------
#pragma mark - Actions
//------------------------------------------------------------------------------

- (void)start
{
#if TARGET_OS_IPHONE
    self.displayLink.paused = NO;
#elif TARGET_OS_MAC
    CVDisplayLinkStart(self.displayLink);
#endif
    self.stopped = NO;
}

//------------------------------------------------------------------------------

- (void)stop
{
#if TARGET_OS_IPHONE
    self.displayLink.paused = YES;
#elif TARGET_OS_MAC
    CVDisplayLinkStop(self.displayLink);
#endif
    self.stopped = YES;
}

//------------------------------------------------------------------------------

- (void)update
{
    if (!self.stopped)
    {
        if ([self.delegate respondsToSelector:@selector(displayLinkNeedsDisplay:)])
        {
            [self.delegate displayLinkNeedsDisplay:self];
        }
    }
}

//------------------------------------------------------------------------------

@end

//------------------------------------------------------------------------------
#pragma mark - CVDisplayLink Callback (Implementation)
//------------------------------------------------------------------------------

#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
static CVReturn KSYAudioDisplayLinkCallback(CVDisplayLinkRef displayLinkRef,
                                           const CVTimeStamp *now,
                                           const CVTimeStamp *outputTime,
                                           CVOptionFlags flagsIn,
                                           CVOptionFlags *flagsOut,
                                           void   *displayLinkContext)
{
    KSYAudioDisplayLink *displayLink = (__bridge KSYAudioDisplayLink*)displayLinkContext;
    [displayLink update];
    return kCVReturnSuccess;
}
#endif
