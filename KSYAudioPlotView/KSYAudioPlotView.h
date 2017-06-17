//
//  KSYAudioPlotView.h
//
//  Created by sunyazhou on 2017/6/16.
//  Copyright © 2017年 Kingsoft, Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
//#import "KSYPlot.h"
#import "KSYAudioDisplayLink.h"

#import "KSYAudioUtilities.h"

//------------------------------------------------------------------------------
#pragma mark - Enumerations
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Plot Types
///-----------------------------------------------------------

/**
 The types of plots that can be displayed in the view using the data.
 */
typedef NS_ENUM(NSInteger, KSYPlotType)
{
    /**
     Plot that displays only the samples of the current buffer
     */
    KSYPlotTypeBuffer,
    
    /**
     Plot that displays a rolling history of values using the RMS calculated for each incoming buffer
     */
    KSYPlotTypeRolling
};


//@class KSYAudio;

//------------------------------------------------------------------------------
#pragma mark - Constants
//------------------------------------------------------------------------------

/**
 The default value used for the maximum rolling history buffer length of any KSYAudioPlot.
 @deprecated This constant is deprecated starting in version 0.2.0.
 @note Please use KSYAudioPlotDefaultMaxHistoryBufferLength instead.
 */
FOUNDATION_EXPORT UInt32 const kKSYAudioPlotMaxHistoryBufferLength __attribute__((deprecated));

/**
 The default value used for the default rolling history buffer length of any KSYAudioPlot.
 @deprecated This constant is deprecated starting in version 0.2.0.
 @note Please use KSYAudioPlotDefaultHistoryBufferLength instead.
 */
FOUNDATION_EXPORT UInt32 const kKSYAudioPlotDefaultHistoryBufferLength __attribute__((deprecated));

/**
 The default value used for the default rolling history buffer length of any KSYAudioPlot.
 */
FOUNDATION_EXPORT UInt32 const KSYAudioPlotDefaultHistoryBufferLength;

/**
 The default value used for the maximum rolling history buffer length of any KSYAudioPlot.
 */
FOUNDATION_EXPORT UInt32 const KSYAudioPlotDefaultMaxHistoryBufferLength;

//------------------------------------------------------------------------------
#pragma mark - KSYAudioPlotWaveformLayer
//------------------------------------------------------------------------------

/**
 The KSYAudioPlotWaveformLayer is a lightweight subclass of the CAShapeLayer that allows implicit animations on the `path` key.
 */
@interface KSYAudioPlotWaveformLayer : CAShapeLayer
@end

//------------------------------------------------------------------------------
#pragma mark - KSYAudioPlot
//------------------------------------------------------------------------------
//@interface KSYAudioPlot : KSYPlot
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
@interface KSYAudioPlotView : UIView
#elif TARGET_OS_MAC
#import <Cocoa/Cocoa.h>
@interface KSYAudioPlotView : NSView
#endif

//------------------------------------------------------------------------------
#pragma mark - Properties
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Customizing The Plot's Appearance
///-----------------------------------------------------------
/**
 The default background color of the plot. For iOS the color is specified as a UIColor while for OSX the color is an NSColor. The default value on both platforms is black.
 */
#if TARGET_OS_IPHONE
@property (nonatomic, strong) IBInspectable UIColor *backgroundColor;
#elif TARGET_OS_MAC
@property (nonatomic, strong) IBInspectable NSColor *backgroundColor;
#endif

/**
 The default color of the plot's data (i.e. waveform, y-axis values). For iOS the color is specified as a UIColor while for OSX the color is an NSColor. The default value on both platforms is red.
 */
#if TARGET_OS_IPHONE
@property (nonatomic, strong) IBInspectable UIColor *color;
#elif TARGET_OS_MAC
@property (nonatomic, strong) IBInspectable NSColor *color;
#endif

/**
 The plot's gain value, which controls the scale of the y-axis values. The default value of the gain is 1.0f and should always be greater than 0.0f.
 */
@property (nonatomic, assign) IBInspectable float gain;

/**
 The type of plot as specified by the `KSYPlotType` enumeration (i.e. a buffer or rolling plot type).
 */
@property (nonatomic, assign) IBInspectable KSYPlotType plotType;

/**
 A boolean indicating whether or not to fill in the graph. A value of YES will make a filled graph (filling in the space between the x-axis and the y-value), while a value of NO will create a stroked graph (connecting the points along the y-axis).
 */
@property (nonatomic, assign) IBInspectable BOOL shouldFill;

/**
 A boolean indicating whether the graph should be rotated along the x-axis to give a mirrored reflection. This is typical for audio plots to produce the classic waveform look. A value of YES will produce a mirrored reflection of the y-values about the x-axis, while a value of NO will only plot the y-values.
 */
@property (nonatomic, assign) IBInspectable BOOL shouldMirror;

/**
 A BOOL that allows optimizing the audio plot's drawing for real-time displays. Since the update function may be updating the plot's data very quickly (over 60 frames per second) this property will throttle the drawing calls to be 60 frames per second (or whatever the screen rate is). Specifically, it disables implicit path change animations on the `waveformLayer` and sets up a display link to render 60 fps (audio updating the plot at 44.1 kHz causes it to re-render 86 fps - far greater than what is needed for a visual display).
 */
@property (nonatomic, assign) BOOL shouldOptimizeForRealtimePlot;

//------------------------------------------------------------------------------

/**
 A BOOL indicating whether the plot should center itself vertically.
 */
@property (nonatomic, assign) BOOL shouldCenterYAxis;

//------------------------------------------------------------------------------

/**
 An KSYAudioPlotWaveformLayer that is used to render the actual waveform. By switching the drawing code to Core Animation layers in version 0.2.0 most work, specifically the compositing step, is now done on the GPU. Hence, multiple KSYAudioPlot instances can be used simultaneously with very low CPU overhead so these are now practical for table and collection views.
 */
@property (nonatomic, strong) KSYAudioPlotWaveformLayer *waveformLayer;

//------------------------------------------------------------------------------
#pragma mark - Adjust Resolution
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Adjusting The Resolution
///-----------------------------------------------------------

/**
 Sets the length of the rolling history buffer (i.e. the number of points in the rolling plot's buffer). Can grow or shrink the display up to the maximum size specified by the `maximumRollingHistoryLength` method. Will return the actual set value, which will be either the given value if smaller than the `maximumRollingHistoryLength` or `maximumRollingHistoryLength` if a larger value is attempted to be set.
 @param  historyLength The new length of the rolling history buffer.
 @return The new value equal to the historyLength or the `maximumRollingHistoryLength`.
 */
-(int)setRollingHistoryLength:(int)historyLength;

//------------------------------------------------------------------------------

/**
 Provides the length of the rolling history buffer (i.e. the number of points in the rolling plot's buffer).
 *  @return An int representing the length of the rolling history buffer
 */
-(int)rollingHistoryLength;

//------------------------------------------------------------------------------
#pragma mark - Subclass Methods
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Subclass Methods
///-----------------------------------------------------------

/**
 Main method that handles converting the points created from the `updatedBuffer:withBufferSize:` method into a CGPathRef to store in the `waveformLayer`. In this method you can create any path you'd like using the point array (for instance, maybe mapping the points to a circle instead of the standard 2D plane).
 @param points     An array of CGPoint structures, with the x values ranging from 0 - (pointCount - 1) and y values containing the last audio data's buffer.
 @param pointCount A UInt32 of the length of the point array.
 @param rect       An KSYRect (CGRect on iOS or NSRect on OSX) that the path should be created relative to.
 @return A CGPathRef that is the path you'd like to store on the `waveformLayer` to visualize the audio data.
 */
- (CGPathRef)createPathWithPoints:(CGPoint *)points
                       pointCount:(UInt32)pointCount
                           inRect:(KSYRect)rect;

//------------------------------------------------------------------------------

/**
 Provides the default length of the rolling history buffer when the plot is initialized. Default is `KSYAudioPlotDefaultHistoryBufferLength` constant.
 @return An int describing the initial length of the rolling history buffer.
 */
- (int)defaultRollingHistoryLength;

//------------------------------------------------------------------------------

/**
 Called after the view has been created. Subclasses should use to add any additional methods needed instead of overriding the init methods.
 */
- (void)setupPlot;

//------------------------------------------------------------------------------

/**
 Provides the default number of points that will be used to initialize the graph's points data structure that holds. Essentially the plot starts off as a flat line of this many points. Default is 100.
 @return An int describing the initial number of points the plot should have when flat lined.
 */
- (int)initialPointCount;

//------------------------------------------------------------------------------

/**
 Provides the default maximum rolling history length - that is, the maximum amount of points the `setRollingHistoryLength:` method may be set to. If a length higher than this is set then the plot will likely crash because the appropriate resources are only allocated once during the plot's initialization step. Defualt is `KSYAudioPlotDefaultMaxHistoryBufferLength` constant.
 @return An int describing the maximum length of the absolute rolling history buffer.
 */
- (int)maximumRollingHistoryLength;

//------------------------------------------------------------------------------

/**
 Method to cause the waveform layer's path to get recreated and redrawn on screen using the last buffer of data provided. This is the equivalent to the drawRect: method used to normally subclass a view's drawing. This normally don't need to be overrode though - a better approach would be to override the `createPathWithPoints:pointCount:inRect:` method.
 */
- (void)redraw;

//------------------------------------------------------------------------------

/**
 Main method used to copy the sample data from the source buffer and update the
 plot. Subclasses can overwrite this method for custom behavior.
 @param data   A float array of the sample data. Subclasses should copy this data to a separate array to avoid threading issues.
 @param length The length of the float array as an int.
 */
-(void)setSampleData:(float *)data length:(int)length;

//------------------------------------------------------------------------------

#pragma mark - Clearing
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Clearing The Plot
///-----------------------------------------------------------

/**
 Clears all data from the audio plot (includes both KSYPlotTypeBuffer and KSYPlotTypeRolling)
 */
-(void)clear;

//------------------------------------------------------------------------------
#pragma mark - Get Samples
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Updating The Plot
///-----------------------------------------------------------

/**
 Updates the plot with the new buffer data and tells the view to redraw itself. Caller will provide a float array with the values they expect to see on the y-axis. The plot will internally handle mapping the x-axis and y-axis to the current view port, any interpolation for fills effects, and mirroring.
 @param buffer     A float array of values to map to the y-axis.
 @param bufferSize The size of the float array that will be mapped to the y-axis.
 @warning The bufferSize is expected to be the same, constant value once initial triggered. For plots using OpenGL a vertex buffer object will be allocated with a maximum buffersize of (2 * the initial given buffer size) to account for any interpolation necessary for filling in the graph. Updates use the glBufferSubData(...) function, which will crash if the buffersize exceeds the initial maximum allocated size.
 */
-(void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize;
@end

@interface KSYAudioPlotView () <KSYAudioDisplayLinkDelegate>
@property (nonatomic, strong) KSYAudioDisplayLink *displayLink;
@property (nonatomic, assign) KSYPlotHistoryInfo  *historyInfo;
@property (nonatomic, assign) CGPoint            *points;
@property (nonatomic, assign) UInt32              pointCount;
@end
