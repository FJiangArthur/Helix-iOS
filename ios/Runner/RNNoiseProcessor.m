//
//  RNNoiseProcessor.m
//  Runner
//
//  ObjC wrapper around the RNNoise C library for noise reduction.
//  TODO: Add RNNoise C source files from https://github.com/xiph/rnnoise
//        (BSD-licensed). Once added, uncomment the #import and implementation
//        sections below, and set _isAvailable = YES in init.
//

#import "RNNoiseProcessor.h"

// TODO: Uncomment when RNNoise C sources are added to the project:
// #import "rnnoise.h"

// RNNoise operates on 480-sample frames at 48kHz.
static const int kRNNoiseFrameSize = 480;
// Resampling ratio: 48kHz / 16kHz = 3
static const int kResampleRatio = 3;
// Input frame size at 16kHz: 480 / 3 = 160 samples
static const int kInputFrameSize = 160;

@implementation RNNoiseProcessor {
    // TODO: Uncomment when RNNoise C sources are added:
    // DenoiseState *_denoiseState;
    float _lastVadProbability;
    BOOL _isAvailable;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastVadProbability = 0.0;
        _isAvailable = NO;

        if (!_isAvailable) {
            NSLog(@"[RNNoiseProcessor] RNNoise C sources not yet available. "
                  @"Noise reduction will pass through audio unchanged. "
                  @"Add sources from https://github.com/xiph/rnnoise");
        }
    }
    return self;
}

- (BOOL)isAvailable {
    return _isAvailable;
}

- (float)lastVadProbability {
    return _lastVadProbability;
}

- (NSData *)processPCM16:(NSData *)pcmData {
    if (!_isAvailable) {
        return pcmData;
    }
    return pcmData;
}

- (void)reset {
    _lastVadProbability = 0.0;
}

- (void)destroy {
    _isAvailable = NO;
}

@end
