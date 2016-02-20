/*
 Copyright (c) 2016 akiym. All rights reserved.
 */

/*
 Copyright (c) 2014-2015, Alessandro Gatti
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NESLoader.h"

static NSString *kCPUFamily = @"Generic";
static NSString *kCPUSubFamily = @"6502";

static const size_t kPRGPageSize = 0x4000;
static const size_t kCHRPageSize = 0x2000;

// iNES format http://wiki.nesdev.com/w/index.php/INES
typedef struct {
  uint8_t constant[4];
  uint8_t prg16Size;
  uint8_t chr8Size;
  uint8_t f6;
  uint8_t f7;
  uint8_t prg8Size;
  uint8_t f9;
  uint8_t f10;
  uint8_t reserved[5];
} iNESHeader;

@interface HopperNESLoader () {
  
  /*!
   * Hopper Services provider instance.
   */
  id<HPHopperServices> _services;
}

@end

@implementation HopperNESLoader

- (instancetype)initWithHopperServices:(id<HPHopperServices>)services {
  if (self = [super init]) {
    _services = services;
  }
  return self;
}

- (HopperUUID *)pluginUUID {
  return [_services UUIDWithString:@"91735E85-D9F3-457F-B4DA-DD2EF8D70CDF"];
}

- (HopperPluginType)pluginType {
  return Plugin_Loader;
}

- (NSString *)pluginName {
  return @"NES File";
}

- (NSString *)pluginDescription {
  return @"NES File Loader";
}

- (NSString *)pluginAuthor {
  return @"akiym";
}

- (NSString *)pluginCopyright {
  return @"©2016 akiym";
}

- (NSString *)pluginVersion {
  return @"0.0.1";
}

- (BOOL)canLoadDebugFiles {
  return NO;
}

- (NSArray *)detectedTypesForData:(NSData *)data {
  id<HPDetectedFileType> detectedType = [_services detectedType];
  detectedType.fileDescription = @"NES binary program";
  detectedType.addressWidth = AW_16bits;
  detectedType.cpuFamily = kCPUFamily;
  detectedType.cpuSubFamily = kCPUSubFamily;
  detectedType.shortDescriptionString = @"nes";
  return @[ detectedType ];
}

- (FileLoaderLoadingStatus)loadData:(NSData *)data
              usingDetectedFileType:(DetectedFileType *)fileType
                            options:(FileLoaderOptions)options
                            forFile:(id<HPDisassembledFile>)file
                      usingCallback:(FileLoadingCallbackInfo)callback {
  iNESHeader hdr;
  [data getBytes:&hdr length:sizeof(iNESHeader)];
  size_t fileOffset = sizeof(iNESHeader);
  
  // memory map http://wiki.nesdev.com/w/index.php/CPU_memory_map
  [self addSegmentToFile:file
                 address:0x0
                  length:0x800
                    name:@"2KB internal RAM"];
  [self addSegmentToFile:file
                 address:0x2000
                  length:0x8
                    name:@"NES PPU registers"];
  [self addSegmentToFile:file
                 address:0x4000
                  length:0x20
                    name:@"NES APU and I/O registers"];
  
  BOOL hasTrainer = hdr.f6 & 0x4; // 512-byte trainer at $7000-$71FF (stored before PRG data)
  if (hasTrainer) {
    NSData *trainerData = [NSData dataWithBytes:(data.bytes + fileOffset) length:0x200];
    id<HPSegment> segment;
    segment = [file addSegmentAt:0x7000 size:0x200];
    segment.mappedData = trainerData;
    segment.segmentName = @"Trainer";
    segment.fileOffset = fileOffset;
    segment.fileLength = 0x200;
    fileOffset += 0x200;
  }
  
  unsigned long address = 0x8000;
  unsigned long length = data.length - fileOffset;
  
  NSData *fileData = [NSData dataWithBytes:(data.bytes + fileOffset) length:length];
  id<HPSegment> segment;
  segment = [file addSegmentAt:address size:length];
  segment.mappedData = fileData;
  segment.segmentName = @"ROM";
  segment.fileOffset = fileOffset;
  segment.fileLength = length;
  
  unsigned long fileLength;
  fileLength = kPRGPageSize * hdr.prg16Size;
  [self addSectionAtSegment:segment
                       file:file
                    address:address
                     offset:fileOffset
                     length:fileLength
                       name:@"PRG ROM data"
               containsCode:YES];
  fileOffset += fileLength;
  address += fileLength;
  fileLength = kCHRPageSize * hdr.chr8Size;
  [self addSectionAtSegment:segment
                       file:file
                    address:address
                     offset:fileOffset
                     length:fileLength
                       name:@"CHR ROM data"
               containsCode:NO];
  
  file.cpuFamily = kCPUFamily;
  file.cpuSubFamily = kCPUSubFamily;
  [file setAddressSpaceWidthInBits:16];
  [file addEntryPoint:0x8000];
  
  return DIS_OK;
}

- (FileLoaderLoadingStatus)loadDebugData:(NSData *)data
                                 forFile:(NSObject<HPDisassembledFile> *)file
                           usingCallback:(FileLoadingCallbackInfo)callback {
  return DIS_NotSupported;
}

- (NSData *)extractFromData:(NSData *)data
      usingDetectedFileType:(DetectedFileType *)fileType
         returnAdjustOffset:(uint64_t *)adjustOffset {
  return nil;
}

- (void)fixupRebasedFile:(id<HPDisassembledFile>)file
               withSlide:(int64_t)slide
        originalFileData:(NSData *)fileData {
}

- (void)addSegmentToFile:(id<HPDisassembledFile>)file
                 address:(unsigned long)address
                  length:(unsigned long)length
                    name:(NSString *)segmentName {
  id<HPSegment> segment = [file addSegmentAt:address size:length];
  segment.segmentName = segmentName;
  [file setComment:[NSString stringWithFormat:@"\n%@\n", segmentName]
  atVirtualAddress:address
            reason:CCReason_Script];
}

- (void)addSectionAtSegment:(id<HPSegment>)segment
                       file:(id<HPDisassembledFile>)file
                    address:(unsigned long)address
                     offset:(unsigned long)fileOffset
                     length:(unsigned long)length
                       name:(NSString *)sectionName
               containsCode:(BOOL)containsCode {
  id<HPSection> section = [segment addSectionAt:address size:length];
  section.pureDataSection = NO;
  section.pureCodeSection = NO;
  section.containsCode = containsCode;
  section.fileOffset = fileOffset;
  section.fileLength = length;
  section.sectionName = sectionName;
  [file setComment:[NSString stringWithFormat:@"\nSection %@\n\n"
                    @"Range 0x%lx - 0x%lx (%lu bytes)\n"
                    @"File offset %lu (%lu bytes)\n",
                    sectionName,
                    address, length - 1, length,
                    fileOffset, length]
  atVirtualAddress:address
            reason:CCReason_Script];
}

@end
