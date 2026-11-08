#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CoreVideo.h>
#include <unistd.h>
#include <stdatomic.h>

typedef struct {unsigned frames, errors, dropped; long firstError; size_t width,height; OSType format; double sumMean; unsigned distinct; double previous; } Stats;
static void output(void *ref,void *src,OSStatus status,VTDecodeInfoFlags flags,CVImageBufferRef image,CMTime pts,CMTime dur){
 Stats *s=(Stats*)ref;
 if(status||!image){s->errors++;if(!s->firstError)s->firstError=status?status:-1;return;}
 s->frames++;if(flags&kVTDecodeInfo_FrameDropped)s->dropped++;
 CVPixelBufferRef p=(CVPixelBufferRef)image; s->width=CVPixelBufferGetWidth(p);s->height=CVPixelBufferGetHeight(p);s->format=CVPixelBufferGetPixelFormatType(p);
 CVPixelBufferLockBaseAddress(p,kCVPixelBufferLock_ReadOnly);
 unsigned char *b=CVPixelBufferGetBaseAddressOfPlane(p,0);size_t stride=CVPixelBufferGetBytesPerRowOfPlane(p,0);double total=0;int count=0;
 if(b) for(size_t y=0;y<s->height;y+=23)for(size_t x=0;x<s->width;x+=17){
  total+=(s->format==kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)?(((uint16_t*)(b+y*stride))[x]>>6):b[y*stride+x];count++;
 }
 double mean=count?total/count:0;s->sumMean+=mean;if(s->frames>1&&fabs(mean-s->previous)>0.01)s->distinct++;s->previous=mean;
 CVPixelBufferUnlockBaseAddress(p,kCVPixelBufferLock_ReadOnly);
}
static id hw(VTDecompressionSessionRef s){CFTypeRef v=NULL;OSStatus r=VTSessionCopyProperty(s,kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder,kCFAllocatorDefault,&v);id out=r?@{@"queryStatus":@(r)}:(v?CFBridgingRelease(v):[NSNull null]);return out;}
int main(int argc,const char **argv){ @autoreleasepool {
 if(argc<3){fprintf(stderr,"usage: decode_probe sample.mp4 8|10 [hardware|software]\n");return 2;}
 BOOL forceHardware=argc<4||strcmp(argv[3],"software")!=0;
 NSMutableDictionary *r=[NSMutableDictionary dictionaryWithDictionary:@{@"path":[NSString stringWithUTF8String:argv[1]],@"requiredHardware":@(forceHardware),@"time":[[NSDate date] description]}];
 NSURL *url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
 AVURLAsset *asset=[AVURLAsset URLAssetWithURL:url options:nil];
 NSArray *tracks=[asset tracksWithMediaType:AVMediaTypeVideo];
 if(!tracks.count){fprintf(stderr,"No video track\n");return 3;}
 AVAssetTrack *track=tracks[0]; NSError *e=nil;
 AVAssetReader *reader=[[AVAssetReader alloc] initWithAsset:asset error:&e];
 AVAssetReaderTrackOutput *o=[[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:nil];
 o.alwaysCopiesSampleData=NO;[reader addOutput:o];
 if(![reader startReading]){fprintf(stderr,"reader failed: %s\n",reader.error.description.UTF8String);return 4;}
 CMVideoFormatDescriptionRef desc=(__bridge CMVideoFormatDescriptionRef)track.formatDescriptions[0];
 CMVideoDimensions dims=CMVideoFormatDescriptionGetDimensions(desc);r[@"codedWidth"]=@(dims.width);r[@"codedHeight"]=@(dims.height);
 r[@"formatExtensions"]=[(__bridge NSDictionary*)CMFormatDescriptionGetExtensions(desc) description];
 NSDictionary *spec=forceHardware?@{(__bridge NSString*)kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder:@YES,(__bridge NSString*)kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder:@YES}:@{(__bridge NSString*)kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder:@NO};
 OSType fmt=atoi(argv[2])==10?kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
 NSDictionary *attrs=@{(__bridge NSString*)kCVPixelBufferPixelFormatTypeKey:@(fmt),(__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
 Stats stats={0};VTDecompressionOutputCallbackRecord callback={output,&stats};VTDecompressionSessionRef session=NULL;
 OSStatus cr=VTDecompressionSessionCreate(kCFAllocatorDefault,desc,(__bridge CFDictionaryRef)spec,(__bridge CFDictionaryRef)attrs,&callback,&session);
 r[@"createStatus"]=@(cr); unsigned input=0,submitErrors=0,emptyMarkers=0;long firstSubmit=0;NSMutableArray *failures=[NSMutableArray array];
 if(!cr&&session){
  r[@"usingHardwareBefore"]=hw(session);
  for(;;){CMSampleBufferRef sb=[o copyNextSampleBuffer];if(!sb)break;
   CMItemCount ns=CMSampleBufferGetNumSamples(sb);size_t bytes=CMSampleBufferGetTotalSampleSize(sb);
   if(ns==0||bytes==0){emptyMarkers++;CFRelease(sb);if(emptyMarkers>8)break;continue;}
   VTDecodeInfoFlags flags=0; OSStatus er=VTDecompressionSessionDecodeFrame(session,sb,0,NULL,&flags);input++;
   if(er){submitErrors++;if(!firstSubmit)firstSubmit=er;[failures addObject:@{@"status":@(er),@"index":@(input),@"sampleCount":@(ns),@"sampleBytes":@(bytes),@"pts":@(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb)))}];}CFRelease(sb);
   if(submitErrors>=3||stats.errors>=3)break;
   usleep(20000);
  }
  OSStatus finish=VTDecompressionSessionFinishDelayedFrames(session);
  OSStatus wait=VTDecompressionSessionWaitForAsynchronousFrames(session);
  r[@"finishStatus"]=@(finish);r[@"waitStatus"]=@(wait);r[@"usingHardwareAfter"]=hw(session);
  VTDecompressionSessionInvalidate(session);CFRelease(session);
 }
 [reader cancelReading];
 r[@"emptyMarkers"]=@(emptyMarkers);r[@"submissionFailures"]=failures;
 r[@"submittedSamples"]=@(input);r[@"submitErrors"]=@(submitErrors);r[@"firstSubmitError"]=@(firstSubmit);
 r[@"decodedFrames"]=@(stats.frames);r[@"callbackErrors"]=@(stats.errors);r[@"firstCallbackError"]=@(stats.firstError);r[@"droppedFlags"]=@(stats.dropped);
 r[@"decodedWidth"]=@(stats.width);r[@"decodedHeight"]=@(stats.height);r[@"pixelFormat"]=@(stats.format);
 r[@"meanLuma"]=@(stats.frames?stats.sumMean/stats.frames:0);r[@"frameMeanChanges"]=@(stats.distinct);
 NSData *data=[NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingPrettyPrinted error:&e];fwrite(data.bytes,1,data.length,stdout);fputs("\n",stdout);
 return cr||submitErrors||stats.errors||stats.frames!=input||!input?1:0;
 }}
