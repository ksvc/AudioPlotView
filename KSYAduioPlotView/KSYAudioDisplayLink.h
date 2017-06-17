//
//  KSYAudioDisplayLink.h
//  EditDemo
//
//  Created by sunyazhou on 2017/6/15.
//  Copyright © 2017年 Kingsoft, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@class KSYAudioDisplayLink;

//------------------------------------------------------------------------------
#pragma mark - KSYAudioDisplayLinkDelegate
//------------------------------------------------------------------------------

/**
 The KSYAudioDisplayLinkDelegate provides a means for an KSYAudioDisplayLink instance to notify a receiver when it should redraw itself.
 */
@protocol KSYAudioDisplayLinkDelegate <NSObject>

@required
/**
 Required method for an KSYAudioDisplayLinkDelegate to implement. This fires at the screen's display rate (typically 60 fps).
 @param displayLink An KSYAudioDisplayLink instance used by a receiver to draw itself at the screen's refresh rate.
 */
- (void)displayLinkNeedsDisplay:(KSYAudioDisplayLink *)displayLink;

@end

//------------------------------------------------------------------------------
#pragma mark - KSYAudioDisplayLink
//------------------------------------------------------------------------------

/**
 The KSYAudioDisplayLink provides a cross-platform (iOS and Mac) abstraction over the CADisplayLink for iOS and CVDisplayLink for Mac. The purpose of this class is to provide an accurate timer for views that need to redraw themselves at 60 fps. This class is used by the KSYAudioPlot and, eventually, the KSYAudioPlotGL to provide a timer mechanism to draw real-time plots.
*/

@interface KSYAudioDisplayLink : NSObject
//------------------------------------------------------------------------------
#pragma mark - Class Methods
//------------------------------------------------------------------------------

/**
 Class method to create an KSYAudioDisplayLink. The caller should implement the KSYAudioDisplayLinkDelegate protocol to receive the `displayLinkNeedsDisplay:` delegate method to know when to redraw itself.
 @param delegate An instance that implements the KSYAudioDisplayLinkDelegate protocol.
 @return An instance of the KSYAudioDisplayLink.
 */
+ (instancetype)displayLinkWithDelegate:(id<KSYAudioDisplayLinkDelegate>)delegate;

//------------------------------------------------------------------------------
#pragma mark - Properties
//------------------------------------------------------------------------------

/**
 The KSYAudioDisplayLinkDelegate for which to receive the redraw calls.
 */
@property (nonatomic, weak) id<KSYAudioDisplayLinkDelegate> delegate;

//------------------------------------------------------------------------------
#pragma mark - Instance Methods
//------------------------------------------------------------------------------

/**
 Method to start the display link and provide the `displayLinkNeedsDisplay:` calls to the `delegate`
 */
- (void)start;

/**
 Method to stop the display link from providing the `displayLinkNeedsDisplay:` calls to the `delegate`
 */
- (void)stop;

//------------------------------------------------------------------------------


@end
