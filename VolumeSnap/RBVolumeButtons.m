//
//  RBVolumeButtons.m
//  VolumeSnap
//
//  Created by Randall Brown on 11/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "RBVolumeButtons.h"
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>

@interface RBVolumeButtons()
-(void)initializeVolumeButtonStealer;
-(void)volumeDown;
-(void)volumeUp;
-(void)startStealingVolumeButtonEvents;
-(void)stopStealingVolumeButtonEvents;

@property BOOL isStealingVolumeButtons;
@property BOOL suspended;
@property (retain) UIView *volumeView;

@property (nonatomic) BOOL hadToLowerVolume;
@property (nonatomic) BOOL hadToRaiseVolume;

@end

@implementation RBVolumeButtons

@synthesize upBlock;
@synthesize downBlock;
@synthesize launchVolume;
@synthesize isStealingVolumeButtons = _isStealingVolumeButtons;
@synthesize suspended = _suspended;
@synthesize volumeView = _volumeView;

void volumeListenerCallback (
                             void                      *inClientData,
                             AudioSessionPropertyID    inID,
                             UInt32                    inDataSize,
                             const void                *inData
                             );
void volumeListenerCallback (
                             void                      *inClientData,
                             AudioSessionPropertyID    inID,
                             UInt32                    inDataSize,
                             const void                *inData
                             ){
    const float *volumePointer = inData;
    float volume = *volumePointer;
    
    
    if( volume > [(RBVolumeButtons*)inClientData launchVolume] )
    {
        RBVolumeButtons *volumeBtn = (RBVolumeButtons *)inClientData;
        [(RBVolumeButtons*)inClientData volumeUp];
        
    }
    else if( volume < [(RBVolumeButtons*)inClientData launchVolume] )
    {
        [(RBVolumeButtons*)inClientData volumeDown];
    }
    
}

-(void)volumeDown
{
    AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume, volumeListenerCallback, self);
    
    [[MPMusicPlayerController applicationMusicPlayer] setVolume:launchVolume];
    
    [self performSelector:@selector(initializeVolumeButtonStealer) withObject:self afterDelay:0.1];
    
    
    if( self.downBlock )
    {
        self.downBlock();
    }
}

-(void)volumeUp
{
    AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume, volumeListenerCallback, self);
    
    [[MPMusicPlayerController applicationMusicPlayer] setVolume:launchVolume];
    
    [self performSelector:@selector(initializeVolumeButtonStealer) withObject:self afterDelay:0.1];
    
    
    if( self.upBlock )
    {
        self.upBlock();
    }
    
}

-(id)init
{
    self = [super init];
    if( self )
    {
        self.isStealingVolumeButtons = NO;
        self.suspended = NO;
    }
    return self;
}

-(void)startStealingVolumeButtonEvents
{
    NSAssert([[NSThread currentThread] isMainThread], @"This must be called from the main thread");
    
    if(self.isStealingVolumeButtons) {
        return;
    }
    
    self.isStealingVolumeButtons = YES;
    
    AudioSessionInitialize(NULL, NULL, NULL, NULL);
    AudioSessionSetActive(YES);
    
    launchVolume = [[MPMusicPlayerController applicationMusicPlayer] volume];
    self.hadToLowerVolume = launchVolume == 1.0;
    self.hadToRaiseVolume = launchVolume == 0.0;
    
    CGRect frame = CGRectMake(0, -100, 10, 10);
    self.volumeView = [[[MPVolumeView alloc] initWithFrame:frame] autorelease];
    [self.volumeView sizeToFit];
    [[[[UIApplication sharedApplication] windows] objectAtIndex:0] addSubview:self.volumeView];
    UIWindow *window = [[UIApplication sharedApplication] windows].firstObject;
    [window setNeedsLayout];
    [window layoutIfNeeded];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.hadToLowerVolume || self.hadToRaiseVolume)
            {
                dispatch_async(dispatch_get_current_queue(), ^{
                    if( self.hadToLowerVolume )
                    {
                        [[MPMusicPlayerController applicationMusicPlayer] setVolume:0.95];
                        launchVolume = 0.95;
                        
                        
                    }
                    
                    if( self.hadToRaiseVolume )
                    {
                        [[MPMusicPlayerController applicationMusicPlayer] setVolume:0.05];
                        launchVolume = 0.05;
                        
                        
                    }
                });
            }
            
            [self initializeVolumeButtonStealer];
        });
    });
    
    
    
    
    
    if (!self.suspended)
    {
        // Observe notifications that trigger suspend
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(suspendStealingVolumeButtonEvents:)
                                                     name:UIApplicationWillResignActiveNotification     // -> Inactive
                                                   object:nil];
        
        // Observe notifications that trigger resume
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resumeStealingVolumeButtonEvents:)
                                                     name:UIApplicationDidBecomeActiveNotification      // <- Active
                                                   object:nil];
    }
    
    
}

- (void)suspendStealingVolumeButtonEvents:(NSNotification *)notification
{
    if(self.isStealingVolumeButtons)
    {
        self.suspended = YES; // Call first!
        [self stopStealingVolumeButtonEvents];
    }
}

- (void)resumeStealingVolumeButtonEvents:(NSNotification *)notification
{
    if(self.suspended)
    {
        [self startStealingVolumeButtonEvents];
        self.suspended = NO; // Call last!
    }
}

-(void)stopStealingVolumeButtonEvents
{
    NSAssert([[NSThread currentThread] isMainThread], @"This must be called from the main thread");
    
    if(!self.isStealingVolumeButtons)
    {
        return;
    }
    
    // Stop observing all notifications
    if (!self.suspended)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    
    AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume, volumeListenerCallback, self);
    
    //    if( hadToLowerVolume )
    //    {
    //        [[MPMusicPlayerController applicationMusicPlayer] setVolume:1.0];
    //    }
    //
    //    if( hadToRaiseVolume )
    //    {
    //        [[MPMusicPlayerController applicationMusicPlayer] setVolume:0.0];
    //    }
    
    [self.volumeView removeFromSuperview];
    self.volumeView = nil;
    
    //    AudioSessionSetActive(NO);
    
    self.isStealingVolumeButtons = NO;
}

-(void)dealloc
{
    self.suspended = NO;
    [self stopStealingVolumeButtonEvents];
    
    self.upBlock = nil;
    self.downBlock = nil;
    [super dealloc];
}

-(void)initializeVolumeButtonStealer
{
    AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume, volumeListenerCallback, self);
}

@end
