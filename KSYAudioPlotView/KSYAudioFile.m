//
//  KSYAudioFile.m
//  EditDemo
//
//  Created by sunyazhou on 2017/6/15.
//  Copyright © 2017年 Kingsoft, Inc. All rights reserved.
//

#import "KSYAudioFile.h"
#import "KSYAudioUtilities.h"
#include <pthread.h>
// constants
static UInt32 KSYAudioFileWaveformDefaultResolution = 1024;
static NSString *KSYAudioFileWaveformDataQueueIdentifier = @"com.KSYaudio.waveformQueue";

//------------------------------------------------------------------------------

typedef struct
{
    AudioFileID                 audioFileID;
    AudioStreamBasicDescription clientFormat;
    NSTimeInterval              duration;
    ExtAudioFileRef             extAudioFileRef;
    AudioStreamBasicDescription fileFormat;
    SInt64                      frames;
    CFURLRef                    sourceURL;
} KSYAudioFileInfo;

//------------------------------------------------------------------------------
#pragma mark - KSYAudioFile
//------------------------------------------------------------------------------

@interface KSYAudioFile ()

@property (nonatomic)         float                 **floatData;
@property (nonatomic)         KSYAudioFileInfo        *info;
@property (nonatomic)         pthread_mutex_t         lock;
@property (nonatomic)         dispatch_queue_t        waveformQueue;
@end

@implementation KSYAudioFile
//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)dealloc
{
    pthread_mutex_destroy(&_lock);
    [KSYAudioUtilities freeFloatBuffers:self.floatData numberOfChannels:self.clientFormat.mChannelsPerFrame];
    [KSYAudioUtilities checkResult:ExtAudioFileDispose(self.info->extAudioFileRef) operation:"Failed to dispose of ext audio file"];
    free(self.info);
}

//------------------------------------------------------------------------------
#pragma mark - Initialization
//------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.info = (KSYAudioFileInfo *)malloc(sizeof(KSYAudioFileInfo));
        _floatData = NULL;
        pthread_mutex_init(&_lock, NULL);
        _waveformQueue = dispatch_queue_create(KSYAudioFileWaveformDataQueueIdentifier.UTF8String, DISPATCH_QUEUE_PRIORITY_DEFAULT);
    }
    return self;
}

//------------------------------------------------------------------------------

- (instancetype)initWithURL:(NSURL *)url
{
    return [self initWithURL:url delegate:nil];
}

//------------------------------------------------------------------------------

- (instancetype)initWithURL:(NSURL *)url
                   delegate:(id<KSYAudioFileDelegate>)delegate
{
    return [self initWithURL:url
                    delegate:delegate
                clientFormat:[self.class defaultClientFormat]];
}

//------------------------------------------------------------------------------

- (instancetype)initWithURL:(NSURL *)url
                   delegate:(id<KSYAudioFileDelegate>)delegate
               clientFormat:(AudioStreamBasicDescription)clientFormat
{
    self = [self init];
    if (self)
    {
        self.info->sourceURL = (__bridge CFURLRef)(url);
        self.info->clientFormat = clientFormat;
        self.delegate = delegate;
        if (![self setup])
        {
            return nil;
        }
    }
    return self;
}

//------------------------------------------------------------------------------
#pragma mark - Class Initializers
//------------------------------------------------------------------------------

+ (instancetype)audioFileWithURL:(NSURL *)url
{
    return [[self alloc] initWithURL:url];
}

//------------------------------------------------------------------------------

+ (instancetype)audioFileWithURL:(NSURL *)url
                        delegate:(id<KSYAudioFileDelegate>)delegate
{
    return [[self alloc] initWithURL:url delegate:delegate];
}

//------------------------------------------------------------------------------

+ (instancetype)audioFileWithURL:(NSURL *)url
                        delegate:(id<KSYAudioFileDelegate>)delegate
                    clientFormat:(AudioStreamBasicDescription)clientFormat
{
    return [[self alloc] initWithURL:url
                            delegate:delegate
                        clientFormat:clientFormat];
}

//------------------------------------------------------------------------------
#pragma mark - NSCopying
//------------------------------------------------------------------------------

- (id)copyWithZone:(NSZone *)zone
{
    return [KSYAudioFile audioFileWithURL:self.url];
}

//------------------------------------------------------------------------------
#pragma mark - Class Methods
//------------------------------------------------------------------------------

+ (AudioStreamBasicDescription)defaultClientFormat
{
    return [KSYAudioUtilities stereoFloatNonInterleavedFormatWithSampleRate:[self defaultClientFormatSampleRate]];
}

//------------------------------------------------------------------------------

+ (Float64)defaultClientFormatSampleRate
{
    return 44100.0f;
}

//------------------------------------------------------------------------------

+ (NSArray *)supportedAudioFileTypes
{
    return @
    [
     @"aac",
     @"caf",
     @"aif",
     @"aiff",
     @"aifc",
     @"mp3",
     @"mp4",
     @"m4a",
     @"snd",
     @"au",
     @"sd2",
     @"wav"
     ];
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (BOOL)setup
{
    //
    // Try to open the file, bail if the file could not be opened
    //
    BOOL success = [self openAudioFile];
    if (!success)
    {
        return success;
    }
    
    //
    // Set the client format
    //
    self.clientFormat = self.info->clientFormat;
    
    return YES;
}

//------------------------------------------------------------------------------
#pragma mark - Creating/Opening Audio File
//------------------------------------------------------------------------------

- (BOOL)openAudioFile
{
    //
    // Need a source url
    //
    NSAssert(self.info->sourceURL, @"KSYAudioFile cannot be created without a source url!");
    
    //
    // Determine if the file actually exists
    //
    CFURLRef url = self.info->sourceURL;
    NSURL *fileURL = (__bridge NSURL *)(url);
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path];
    
    //
    // Create an ExtAudioFileRef for the file handle
    //
    if (fileExists)
    {
        [KSYAudioUtilities checkResult:ExtAudioFileOpenURL(url, &self.info->extAudioFileRef)
                            operation:"Failed to create ExtAudioFileRef"];
    }
    else
    {
        return NO;
    }
    
    //
    // Get the underlying AudioFileID
    //
    UInt32 propSize = sizeof(self.info->audioFileID);
    [KSYAudioUtilities checkResult:ExtAudioFileGetProperty(self.info->extAudioFileRef,
                                                          kExtAudioFileProperty_AudioFile,
                                                          &propSize,
                                                          &self.info->audioFileID)
                        operation:"Failed to get underlying AudioFileID"];
    
    //
    // Store the file format
    //
    propSize = sizeof(self.info->fileFormat);
    [KSYAudioUtilities checkResult:ExtAudioFileGetProperty(self.info->extAudioFileRef,
                                                          kExtAudioFileProperty_FileDataFormat,
                                                          &propSize,
                                                          &self.info->fileFormat)
                        operation:"Failed to get file audio format on existing audio file"];
    
    //
    // Get the total frames and duration
    //
    propSize = sizeof(SInt64);
    [KSYAudioUtilities checkResult:ExtAudioFileGetProperty(self.info->extAudioFileRef,
                                                          kExtAudioFileProperty_FileLengthFrames,
                                                          &propSize,
                                                          &self.info->frames)
                        operation:"Failed to get total frames"];
    self.info->duration = (NSTimeInterval) self.info->frames / self.info->fileFormat.mSampleRate;
    
    return YES;
}

//------------------------------------------------------------------------------
#pragma mark - Events
//------------------------------------------------------------------------------

- (void)seekToFrame:(SInt64)frame
{
    if (pthread_mutex_trylock(&_lock) == 0)
    {
        [KSYAudioUtilities checkResult:ExtAudioFileSeek(self.info->extAudioFileRef,
                                                       frame)
                            operation:"Failed to seek frame position within audio file"];
        
        pthread_mutex_unlock(&_lock);
        
        //
        // Notify delegate
        //
        if ([self.delegate respondsToSelector:@selector(audioFileUpdatedPosition:)])
        {
            [self.delegate audioFileUpdatedPosition:self];
        }
        
        //
        // Deprecated, but supported until 1.0
        //
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        if ([self.delegate respondsToSelector:@selector(audioFile:updatedPosition:)])
        {
            [self.delegate audioFile:self updatedPosition:[self frameIndex]];
        }
#pragma GCC diagnostic pop
    }
}

//------------------------------------------------------------------------------
#pragma mark - Getters
//------------------------------------------------------------------------------

- (AudioStreamBasicDescription)floatFormat
{
    return [KSYAudioUtilities stereoFloatNonInterleavedFormatWithSampleRate:44100.0f];
}

//------------------------------------------------------------------------------

- (KSYAudioFloatData *)getWaveformData
{
    return [self getWaveformDataWithNumberOfPoints:KSYAudioFileWaveformDefaultResolution];
}

//------------------------------------------------------------------------------

- (KSYAudioFloatData *)getWaveformDataWithNumberOfPoints:(UInt32)numberOfPoints
{
    KSYAudioFloatData *waveformData;
    if (pthread_mutex_trylock(&_lock) == 0)
    {
        // store current frame
        SInt64 currentFrame = self.frameIndex;
        BOOL interleaved = [KSYAudioUtilities isInterleaved:self.clientFormat];
        UInt32 channels = self.clientFormat.mChannelsPerFrame;
        if (channels == 0)
        {
            // prevent division by zero
            pthread_mutex_unlock(&_lock);
            return nil;
        }
        float **data = (float **)malloc( sizeof(float*) * channels );
        for (int i = 0; i < channels; i++)
        {
            data[i] = (float *)malloc( sizeof(float) * numberOfPoints );
        }
        
        // seek to 0
        [KSYAudioUtilities checkResult:ExtAudioFileSeek(self.info->extAudioFileRef,
                                                       0)
                            operation:"Failed to seek frame position within audio file"];
        
        // calculate the required number of frames per buffer
        SInt64 framesPerBuffer = ((SInt64) self.totalClientFrames / numberOfPoints);
        SInt64 framesPerChannel = framesPerBuffer / channels;
        
        // allocate an audio buffer list
        AudioBufferList *audioBufferList = [KSYAudioUtilities audioBufferListWithNumberOfFrames:(UInt32)framesPerBuffer
                                                                              numberOfChannels:self.info->clientFormat.mChannelsPerFrame
                                                                                   interleaved:interleaved];
        
        // read through file and calculate rms at each point
        for (SInt64 i = 0; i < numberOfPoints; i++)
        {
            UInt32 bufferSize = (UInt32) framesPerBuffer;
            [KSYAudioUtilities checkResult:ExtAudioFileRead(self.info->extAudioFileRef,
                                                           &bufferSize,
                                                           audioBufferList)
                                operation:"Failed to read audio data from file waveform"];
            if (interleaved)
            {
                float *buffer = (float *)audioBufferList->mBuffers[0].mData;
                for (int channel = 0; channel < channels; channel++)
                {
                    float channelData[framesPerChannel];
                    for (int frame = 0; frame < framesPerChannel; frame++)
                    {
                        channelData[frame] = buffer[frame * channels + channel];
                    }
                    float rms = [KSYAudioUtilities RMS:channelData length:(UInt32)framesPerChannel];
                    data[channel][i] = rms;
                }
            }
            else
            {
                for (int channel = 0; channel < channels; channel++)
                {
                    float *channelData = audioBufferList->mBuffers[channel].mData;
                    float rms = [KSYAudioUtilities RMS:channelData length:bufferSize];
                    data[channel][i] = rms;
                }
            }
        }
        
        // clean up
        [KSYAudioUtilities freeBufferList:audioBufferList];
        
        // seek back to previous position
        [KSYAudioUtilities checkResult:ExtAudioFileSeek(self.info->extAudioFileRef,
                                                       currentFrame)
                            operation:"Failed to seek frame position within audio file"];
        
        pthread_mutex_unlock(&_lock);
        
        waveformData = [KSYAudioFloatData dataWithNumberOfChannels:channels
                                                          buffers:(float **)data
                                                       bufferSize:numberOfPoints];
        
        // cleanup
        for (int i = 0; i < channels; i++)
        {
            free(data[i]);
        }
        free(data);
    }
    return waveformData;
}

//------------------------------------------------------------------------------

- (void)getWaveformDataWithCompletionBlock:(KSYAudioWaveformDataCompletionBlock)waveformDataCompletionBlock
{
    [self getWaveformDataWithNumberOfPoints:KSYAudioFileWaveformDefaultResolution
                                 completion:waveformDataCompletionBlock];
}

//------------------------------------------------------------------------------

- (void)getWaveformDataWithNumberOfPoints:(UInt32)numberOfPoints
                               completion:(KSYAudioWaveformDataCompletionBlock)completion
{
    if (!completion)
    {
        return;
    }
    
    // async get waveform data
    __weak KSYAudioFile *weakSelf = self;
    dispatch_async(self.waveformQueue, ^{
        KSYAudioFloatData *waveformData = [weakSelf getWaveformDataWithNumberOfPoints:numberOfPoints];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(waveformData.buffers, waveformData.bufferSize);
        });
    });
}

//------------------------------------------------------------------------------

- (AudioStreamBasicDescription)clientFormat
{
    return self.info->clientFormat;
}

//------------------------------------------------------------------------------

- (NSTimeInterval)currentTime
{
    return [KSYAudioUtilities MAP:(float)[self frameIndex]
                         leftMin:0.0f
                         leftMax:(float)[self totalFrames]
                        rightMin:0.0f
                        rightMax:[self duration]];
}

//------------------------------------------------------------------------------

- (NSTimeInterval)duration
{
    return self.info->duration;
}

//------------------------------------------------------------------------------

- (AudioStreamBasicDescription)fileFormat
{
    return self.info->fileFormat;
}

//------------------------------------------------------------------------------

- (NSString *)formattedCurrentTime
{
    return [KSYAudioUtilities displayTimeStringFromSeconds:[self currentTime]];
}

//------------------------------------------------------------------------------

- (NSString *)formattedDuration
{
    return [KSYAudioUtilities displayTimeStringFromSeconds:[self duration]];
}

//------------------------------------------------------------------------------

- (SInt64)frameIndex
{
    SInt64 frameIndex;
    [KSYAudioUtilities checkResult:ExtAudioFileTell(self.info->extAudioFileRef, &frameIndex)
                        operation:"Failed to get frame index"];
    return frameIndex;
}

//------------------------------------------------------------------------------

- (NSDictionary *)metadata
{
    // get size of metadata property (dictionary)
    UInt32          propSize = sizeof(self.info->audioFileID);
    CFDictionaryRef metadata;
    UInt32          writable;
    [KSYAudioUtilities checkResult:AudioFileGetPropertyInfo(self.info->audioFileID,
                                                           kAudioFilePropertyInfoDictionary,
                                                           &propSize,
                                                           &writable)
                        operation:"Failed to get the size of the metadata dictionary"];
    
    // pull metadata
    [KSYAudioUtilities checkResult:AudioFileGetProperty(self.info->audioFileID,
                                                       kAudioFilePropertyInfoDictionary,
                                                       &propSize,
                                                       &metadata)
                        operation:"Failed to get metadata dictionary"];
    
    // cast to NSDictionary
    return (__bridge NSDictionary*)metadata;
}

//------------------------------------------------------------------------------

- (NSTimeInterval)totalDuration
{
    return self.info->duration;
}

//------------------------------------------------------------------------------

- (SInt64)totalClientFrames
{
    SInt64 totalFrames = [self totalFrames];
    AudioStreamBasicDescription clientFormat = self.info->clientFormat;
    AudioStreamBasicDescription fileFormat = self.info->fileFormat;
    BOOL sameSampleRate = clientFormat.mSampleRate == fileFormat.mSampleRate;
    if (!sameSampleRate)
    {
        totalFrames = self.info->duration * clientFormat.mSampleRate;
    }
    return totalFrames;
}

//------------------------------------------------------------------------------

- (SInt64)totalFrames
{
    return self.info->frames;
}

//------------------------------------------------------------------------------

- (NSURL *)url
{
    return (__bridge NSURL*)self.info->sourceURL;
}

//------------------------------------------------------------------------------
#pragma mark - Setters
//------------------------------------------------------------------------------

- (void)setClientFormat:(AudioStreamBasicDescription)clientFormat
{
    //
    // Clear any float data currently cached
    //
    if (self.floatData)
    {
        self.floatData = nil;
    }
    
    //
    // Client format can only be linear PCM!
    //
    NSAssert([KSYAudioUtilities isLinearPCM:clientFormat], @"Client format must be linear PCM");
    
    //
    // Store the client format
    //
    self.info->clientFormat = clientFormat;
    
    //
    // Set the client format on the ExtAudioFileRef
    //
    [KSYAudioUtilities checkResult:ExtAudioFileSetProperty(self.info->extAudioFileRef,
                                                          kExtAudioFileProperty_ClientDataFormat,
                                                          sizeof(clientFormat),
                                                          &clientFormat)
                        operation:"Couldn't set client data format on file"];
    
    //
    // Create a new float converter using the client format as the input format
    
    //
    // Determine how big our float buffers need to be to hold a buffer of float
    // data for the audio received callback.
    //
    UInt32 maxPacketSize;
    UInt32 propSize = sizeof(maxPacketSize);
    [KSYAudioUtilities checkResult:ExtAudioFileGetProperty(self.info->extAudioFileRef,
                                                          kExtAudioFileProperty_ClientMaxPacketSize,
                                                          &propSize,
                                                          &maxPacketSize)
                        operation:"Failed to get max packet size"];
    
    self.floatData = [KSYAudioUtilities floatBuffersWithNumberOfFrames:1024
                                                     numberOfChannels:self.clientFormat.mChannelsPerFrame];
}

//------------------------------------------------------------------------------

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
    NSAssert(currentTime < [self duration], @"Invalid seek operation, expected current time to be less than duration");
    SInt64 frame = [KSYAudioUtilities MAP:currentTime
                                 leftMin:0.0f
                                 leftMax:[self duration]
                                rightMin:0.0f
                                rightMax:[self totalFrames]];
    [self seekToFrame:frame];
}

//------------------------------------------------------------------------------
#pragma mark - Description
//------------------------------------------------------------------------------

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ {\n"
            "    url: %@,\n"
            "    duration: %f,\n"
            "    totalFrames: %lld,\n"
            "    metadata: %@,\n"
            "    fileFormat: { %@ },\n"
            "    clientFormat: { %@ } \n"
            "}",
            [super description],
            [self url],
            [self duration],
            [self totalFrames],
            [self metadata],
            [KSYAudioUtilities stringForAudioStreamBasicDescription:[self fileFormat]],
            [KSYAudioUtilities stringForAudioStreamBasicDescription:[self clientFormat]]];
}

//------------------------------------------------------------------------------
@end


//------------------------------------------------------------------------------ AudioData模型相关
#pragma mark - KSYAudioFloatData
//------------------------------------------------------------------------------

@interface KSYAudioFloatData ()
@property (nonatomic, assign, readwrite) int    numberOfChannels;
@property (nonatomic, assign, readwrite) float  **buffers;
@property (nonatomic, assign, readwrite) UInt32 bufferSize;
@end

//------------------------------------------------------------------------------

@implementation KSYAudioFloatData

//------------------------------------------------------------------------------

- (void)dealloc
{
    [KSYAudioUtilities freeFloatBuffers:self.buffers
                       numberOfChannels:self.numberOfChannels];
}

//------------------------------------------------------------------------------

+ (instancetype)dataWithNumberOfChannels:(int)numberOfChannels
                                 buffers:(float **)buffers
                              bufferSize:(UInt32)bufferSize
{
    id data = [[self alloc] init];
    size_t size = sizeof(float) * bufferSize;
    float **buffersCopy = [KSYAudioUtilities floatBuffersWithNumberOfFrames:bufferSize
                                                           numberOfChannels:numberOfChannels];
    for (int i = 0; i < numberOfChannels; i++)
    {
        memcpy(buffersCopy[i], buffers[i], size);
    }
    ((KSYAudioFloatData *)data).buffers = buffersCopy;
    ((KSYAudioFloatData *)data).bufferSize = bufferSize;
    ((KSYAudioFloatData *)data).numberOfChannels = numberOfChannels;
    return data;
}

//------------------------------------------------------------------------------

- (float *)bufferForChannel:(int)channel
{
    float *buffer = NULL;
    if (channel < self.numberOfChannels)
    {
        buffer = self.buffers[channel];
    }
    return buffer;
}

//------------------------------------------------------------------------------

@end

