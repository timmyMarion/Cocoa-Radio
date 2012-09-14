//
//  CSDRDemod.m
//  Cocoa Radio
//
//  Created by William Dillon on 8/28/12.
//  Copyright (c) 2012 Oregon State University (COAS). All rights reserved.
//

#import "dspRoutines.h"

@implementation CSDRDemod

- (id)init
{
    self = [super init];
    if (self != nil) {

        // Setup the intermediate frequency filter
        IFFilter = [[CSDRlowPassComplex alloc] init];
        [IFFilter setGain:1.];
        
        // Setup the audio frequency filter
        AFFilter = [[CSDRlowPassFloat alloc] init];
        [AFFilter setGain:.5];
        
        // Setup the audio frequency rational resampler
        AFResampler = [[CSDRResampler alloc] init];
                
        // Set default sample rates (this will set decimation and interpolation)
        _rfSampleRate = 2048000;
        _rfCorrectedRate = 2048000;
        IFFilter.sampleRate = 2048000;
        
        self.afSampleRate = 44100;
        AFFilter.sampleRate = 44100;
        
        self.ifBandwidth  = 90000;
        self.ifSkirtWidth = 20000;
        IFFilter.bandwidth  = 90000;
        IFFilter.skirtWidth = 20000;

        self.afBandwidth  = 21500;
        self.afSkirtWidth = 10000;
        AFFilter.bandwidth  = self.afSampleRate / 2.;
        AFFilter.skirtWidth = 10000;
    }
    
    return self;
}

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    NSLog(@"Demodulating in the base class!");
    
    return nil;
}

+ (CSDRDemod *)demodulatorWithScheme:(NSString *)scheme
{
    if ([scheme caseInsensitiveCompare:@"WBFM"] == NSOrderedSame) {
        return [[CSDRDemodWBFM alloc] init];
    }

    if ([scheme caseInsensitiveCompare:@"NBFM"] == NSOrderedSame) {
        return [[CSDRDemodNBFM alloc] init];
    }
    
    return nil;
}

#pragma mark Utility routines
int gcd(int a, int b) {
    if (a == 0) return b;
    if (b == 0) return a;
    
    if (a > b) return gcd(a - b, b);
    else       return gcd(a, b - a);
}

- (void)calculateResampleRatio
{
    // Get the GCD between sample rates (makes ints)
    int GCD = gcd(self.rfCorrectedRate, self.afSampleRate);
    
    int interpolator = self.afSampleRate / GCD;
    int decimator    = self.rfCorrectedRate / GCD;
    
    [AFResampler setInterpolator:interpolator];
    [AFResampler setDecimator:decimator];

    if (decimator == 0) {
        NSLog(@"Setting decimator to 0!");
    }
    
//    NSLog(@"Set resample ratio to %d/%d", interpolator, decimator);
}

#pragma mark Getters and Setters
- (void)setRfSampleRate:(float)rfSampleRate
{
    _rfSampleRate = rfSampleRate;
    // Assume corrected rate equals requested until known better
    _rfCorrectedRate = rfSampleRate;
    
    [IFFilter setSampleRate:_rfSampleRate];
    [AFFilter setSampleRate:_rfSampleRate];
    
    [self calculateResampleRatio];
}

- (float)rfSampleRate
{
    return _rfSampleRate;
}

- (void)setRfCorrectedRate:(float)rate
{
    _rfCorrectedRate = rate;
    [self calculateResampleRatio];
}

- (float)rfCorrectedRate
{
    return _rfCorrectedRate;
}

- (void)setAfSampleRate:(float)afSampleRate
{
    _afSampleRate = afSampleRate;
    
    [self calculateResampleRatio];
}

- (float)afSampleRate
{
    return _afSampleRate;
}

- (void)setIfBandwidth:(float)ifBandwidth
{
    [IFFilter setBandwidth:ifBandwidth];
}

- (float)ifBandwidth
{
    return [IFFilter skirtWidth];
}

- (void)setIfSkirtWidth:(float)ifSkirtWidth
{
    [IFFilter setSkirtWidth:ifSkirtWidth];
}

- (float)ifSkirtWidth
{
    return [IFFilter skirtWidth];
}

- (void)setAfBandwidth:(float)afBandwidth
{
    [AFFilter setBandwidth:afBandwidth];
}

- (float)afBandwidth
{
    return [AFFilter skirtWidth];
}

- (void)setAfSkirtWidth:(float)afSkirtWidth
{
    [AFFilter setSkirtWidth:afSkirtWidth];
}

- (float)afSkirtWidth
{
    return [AFFilter skirtWidth];
}

- (float)rfGain
{
    return [IFFilter gain];
}

- (void)setRfGain:(float)rfGain
{
    [IFFilter setGain:rfGain];
}

- (float)afGain
{
    return [AFFilter gain];
}

- (void)setAfGain:(float)afGain
{
    [AFFilter setGain:afGain];
}

- (float)ifMaxBandwidth
{
    return 100000000;
}

- (float)ifMinBandwidth
{
    return      1000;
}

- (float)afMaxBandwidth
{
    return _afSampleRate / 2.;
}

- (float)afMinBandwidth
{
    return 1000;
}

@end

#pragma mark -
@implementation CSDRDemodWBFM

- (id)init
{
    self = [super init];
    if (self) {
    }
    
    return self;
}

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    // Down convert
    NSDictionary *baseBand;
    baseBand = freqXlate(complexInput, self.centerFreq, self.rfSampleRate);
    
    // Low-pass filter
    NSDictionary *filtered;
    filtered = [IFFilter filterDict:baseBand];

    // Quadrature demodulation
    NSData *demodulated;
    demodulated = quadratureDemod(filtered, 1., 0.);

    // Audio Frequency filter
    NSData *audioFiltered;
    audioFiltered = [AFFilter filterData:demodulated];

    // Rational resampling
    NSData *audio;
    audio = [AFResampler resample:audioFiltered];
        
    return audio;
}

// Override the defaults as appropriate for WBFM
- (float)ifMaxBandwidth
{
    return  100000;
}

- (float)ifMinBandwidth
{
    return   50000;
}

@end

@implementation CSDRDemodNBFM

- (id)init
{
    self = [super init];
    if (self) {
        self.ifBandwidth  = 25000;
        self.ifSkirtWidth = 10000;
        
        self.afBandwidth  = self.afSampleRate / 2.;
        self.afSkirtWidth = 10000;
    }
    
    return self;
}

- (NSData *)demodulateData:(NSDictionary *)complexInput
{
    // Down convert
    NSDictionary *baseBand;
    baseBand = freqXlate(complexInput, self.centerFreq, self.rfSampleRate);
    
    // Low-pass filter
    NSDictionary *filtered;
    filtered = [IFFilter filterDict:baseBand];
    
    // Quadrature demodulation
    NSData *demodulated;
    demodulated = quadratureDemod(filtered, 1., 0.);
    
    // Audio Frequency filter
    NSData *audioFiltered;
    audioFiltered = [AFFilter filterData:demodulated];
    
    // Rational resampling
    NSData *audio;
    audio = [AFResampler resample:audioFiltered];
    
    return audio;
}

// Override the defaults as appropriate for NBFM (picks up after WBFM)
- (float)ifMaxBandwidth
{
    return  50000;
}

- (float)ifMinBandwidth
{
    return   5000;
}

@end