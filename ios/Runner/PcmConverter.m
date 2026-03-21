//
//  PcmConverter.m
//  Runner
//
//  Created by Hawk on 2024/3/14.
//

#import "PcmConverter.h"
#import "lc3.h"

@implementation PcmConverter

// Frame length 10ms
static const int dtUs = 10000;
// Sampling rate 48K
static const int srHz = 16000;
// Output bytes after encoding a single frame
static const uint16_t outputByteCount = 20;  // 40
// Buffer size required by the encoder
static unsigned encodeSize;
// Buffer size required by the decoder
static unsigned decodeSize;
// Number of samples in a single frame
static uint16_t sampleOfFrames;
// Number of bytes in a single frame, 16Bits takes up two bytes for the next sample
static uint16_t bytesOfFrames;
// Encoder buffer
static void* encMem = NULL;
// File descriptor of the input file
static int inFd = -1;
// File descriptor of output file
static int outFd = -1;

-(NSMutableData *)decode: (NSData *)lc3data {

    unsigned localDecodeSize = lc3_decoder_size(dtUs, srHz);
    sampleOfFrames = lc3_frame_samples(dtUs, srHz);
    bytesOfFrames = sampleOfFrames*2;

    if (lc3data == nil) {
        printf("Failed to decode Base64 data\n");
        return [[NSMutableData alloc] init];
    }

    void *localDecMem = malloc(localDecodeSize);
    lc3_decoder_t lc3_decoder = lc3_setup_decoder(dtUs, srHz, 0, localDecMem);
    unsigned char *localOutBuf;
    if ((localOutBuf = malloc(bytesOfFrames)) == NULL) {
        printf("Failed to allocate memory for outBuf\n");
        free(localDecMem);
        return [[NSMutableData alloc] init];
    }

    int totalBytes = (int)lc3data.length;
    int bytesRead = 0;

    NSMutableData *pcmData = [[NSMutableData alloc] init];

    while (bytesRead < totalBytes) {
        int bytesToRead = MIN(outputByteCount, totalBytes - bytesRead);
        NSRange range = NSMakeRange(bytesRead, bytesToRead);
        NSData *subdata = [lc3data subdataWithRange:range];
        unsigned char *inBuf = (unsigned char *)subdata.bytes;

        lc3_decode(lc3_decoder, inBuf, bytesToRead, LC3_PCM_FORMAT_S16, localOutBuf, 1);

        NSData *data = [NSData dataWithBytes:localOutBuf length:bytesOfFrames];
        [pcmData appendData:data];
        bytesRead += bytesToRead;
    }

    free(localDecMem);
    free(localOutBuf);

    return pcmData;
}
@end
