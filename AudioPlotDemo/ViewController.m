//
//  ViewController.m
//  AudioPlotDemo
//
//  Created by sunyazhou on 2017/6/17.
//  Copyright © 2017年 Ksyun. All rights reserved.
//

#import "ViewController.h"

#import "KSYAudioPlotView.h"
#import "KSYAudioFile.h"

#define kAudioFileDefault [[NSBundle mainBundle] pathForResource:@"17yeasold" ofType:@"mp3"]

@interface ViewController ()
@property (weak, nonatomic) IBOutlet KSYAudioPlotView *audioPlot;
//
// An EZAudioFile that will be used to load the audio file at the file path specified
//
@property (nonatomic, strong) KSYAudioFile *audioFile;

//------------------------------------------------------------------------------

//
// An EZAudioPlayer that will be used for playback
//
//@property (nonatomic, strong) EZAudioPlayer *player;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //
    // Customizing the audio plot's look
    //
    
    //
    // Background color
    //
    self.audioPlot.backgroundColor = [UIColor colorWithRed: 0.169 green: 0.643 blue: 0.675 alpha: 1];
    
    //
    // Waveform color
    //
    self.audioPlot.color = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    
    //
    // Plot type
    //
    self.audioPlot.plotType = KSYPlotTypeBuffer;
    
    //
    // Fill
    //
    self.audioPlot.shouldFill = YES;
    
    //
    // Mirror
    //
    self.audioPlot.shouldMirror = YES;
    
    //
    // No need to optimze for realtime
    //
    self.audioPlot.shouldOptimizeForRealtimePlot = NO;
    
    //
    // Customize the layer with a shadow for fun
    //
    self.audioPlot.waveformLayer.shadowOffset = CGSizeMake(0.0, 1.0);
    self.audioPlot.waveformLayer.shadowRadius = 0.0;
    self.audioPlot.waveformLayer.shadowColor = [UIColor colorWithRed: 0.069 green: 0.543 blue: 0.575 alpha: 1].CGColor;
    self.audioPlot.waveformLayer.shadowOpacity = 5.0;
    self.audioPlot.waveformLayer.lineWidth = 3;
    
    //
    // Load in the sample file
    //
    [self openFileWithFilePathURL:[NSURL fileURLWithPath:kAudioFileDefault]];
    
    
}

#pragma mark - Action Extensions
//------------------------------------------------------------------------------

- (void)openFileWithFilePathURL:(NSURL*)filePathURL
{
    self.audioFile = [KSYAudioFile audioFileWithURL:filePathURL];
    
    
    //
    // Plot the whole waveform
    //
    self.audioPlot.plotType = KSYPlotTypeBuffer;
    self.audioPlot.shouldFill = YES;
    self.audioPlot.shouldMirror = YES;
    
    //
    // Get the audio data from the audio file
    //
    __weak typeof (self) weakSelf = self;
    [self.audioFile getWaveformDataWithCompletionBlock:^(float **waveformData,
                                                         int length)
     {
         [weakSelf.audioPlot updateBuffer:waveformData[0]
                           withBufferSize:length];
     }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
