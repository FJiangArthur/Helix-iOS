//
//  RNNoiseProcessor.h
//  Runner
//
//  ObjC wrapper around the RNNoise C library for noise reduction.
//  TODO: Add RNNoise C source files from https://github.com/xiph/rnnoise
//        (BSD-licensed). The rnnoise.h header already exists in ios/Runner/lc3/.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wraps RNNoise (Recurrent Neural Network Noise Suppression) for
/// real-time noise reduction on PCM16 audio.
///
/// RNNoise operates on 480-sample frames at 48kHz internally.
/// This wrapper handles resampling 16kHz input to 48kHz, running
/// the RNNoise denoiser, and resampling back to 16kHz.
@interface RNNoiseProcessor : NSObject

/// Whether RNNoise C sources are available and the processor is functional.
/// Returns NO until the RNNoise C sources are added to the project.
@property (nonatomic, readonly) BOOL isAvailable;

/// VAD probability from the last processed frame (0.0 - 1.0).
/// Can be used as an additional voice activity signal.
@property (nonatomic, readonly) float lastVadProbability;

/// Initialize the RNNoise processor.
- (instancetype)init;

/// Process a buffer of PCM16 audio data (16kHz mono, little-endian Int16).
/// Returns denoised PCM16 data of the same format and length.
///
/// If RNNoise is not available (C sources not yet added), this returns
/// the input data unchanged.
///
/// @param pcmData Raw PCM16 audio data at 16kHz mono.
/// @return Denoised PCM16 audio data at 16kHz mono.
- (NSData *)processPCM16:(NSData *)pcmData;

/// Reset internal state (call between recording sessions).
- (void)reset;

/// Clean up RNNoise resources.
- (void)destroy;

@end

NS_ASSUME_NONNULL_END
