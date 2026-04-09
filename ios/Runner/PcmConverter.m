//
//  PcmConverter.m
//  Runner
//
//  Created by Hawk on 2024/3/14.
//

#import "PcmConverter.h"
#import "lc3.h"

@implementation PcmConverter {
    void *_decMem;
    unsigned char *_outBuf;
    lc3_decoder_t _decoder;
    uint16_t _bytesOfFrames;
    // H3: reusable scratch buffer so we don't allocate a fresh NSMutableData
    // for every MIC_DATA packet on the BLE delegate queue (~50/s during
    // streaming). setLength: resizes without reallocating when capacity
    // is already sufficient.
    NSMutableData *_scratchPCM;
}

// Frame length 10ms
static const int dtUs = 10000;
// Sampling rate 16K
static const int srHz = 16000;
// Output bytes after encoding a single frame
static const uint16_t outputByteCount = 20;

-(instancetype)init {
    self = [super init];
    if (self) {
        unsigned decodeSize = lc3_decoder_size(dtUs, srHz);
        uint16_t sampleOfFrames = lc3_frame_samples(dtUs, srHz);
        _bytesOfFrames = sampleOfFrames * 2;

        _decMem = malloc(decodeSize);
        _decoder = lc3_setup_decoder(dtUs, srHz, 0, _decMem);
        _outBuf = malloc(_bytesOfFrames);
        // Pre-size scratch for a typical 400-byte (20 frame) MIC_DATA packet.
        _scratchPCM = [[NSMutableData alloc] initWithCapacity:_bytesOfFrames * 32];
    }
    return self;
}

-(void)dealloc {
    if (_decMem) free(_decMem);
    if (_outBuf) free(_outBuf);
}

-(NSData *)decode:(NSData *)lc3data {
    if (lc3data == nil || _decMem == NULL || _outBuf == NULL) {
        return [NSData data];
    }
    int totalBytes = (int)lc3data.length;
    int frameCount = (totalBytes + outputByteCount - 1) / outputByteCount;
    NSUInteger outBytes = (NSUInteger)frameCount * (NSUInteger)_bytesOfFrames;

    // H3: reuse scratch buffer. setLength: grows in place when capacity is
    // sufficient, avoiding per-packet NSMutableData allocation and the
    // O(n) appendBytes loop's reallocation amortization. Caller (Swift
    // BluetoothManager) bridges `as Data` immediately on the BLE queue,
    // so scratch ownership stays local and single-threaded.
    [_scratchPCM setLength:outBytes];
    unsigned char *dst = (unsigned char *)_scratchPCM.mutableBytes;

    const unsigned char *inputBytes = (const unsigned char *)lc3data.bytes;
    int bytesRead = 0;
    NSUInteger dstOffset = 0;
    while (bytesRead < totalBytes) {
        int bytesToRead = MIN(outputByteCount, totalBytes - bytesRead);
        lc3_decode(_decoder, inputBytes + bytesRead, bytesToRead,
                   LC3_PCM_FORMAT_S16, dst + dstOffset, 1);
        dstOffset += _bytesOfFrames;
        bytesRead += bytesToRead;
    }
    // WS-G H3 fix: scratch buffer aliased with async WS sender; copy on return.
    // The H5 OpenAIRealtimeTranscriber fast path can hold a reference to this
    // buffer asynchronously on the WebSocket queue while the next MIC_DATA
    // packet mutates _scratchPCM via setLength:/lc3_decode. Returning an
    // immutable snapshot defeats the H3 allocation win for OpenAI but keeps
    // the Apple path safe (single-threaded on BLE queue). Apple path also
    // pays for the copy — trade-off accepted over audio corruption.
    return [_scratchPCM copy];
}
@end
