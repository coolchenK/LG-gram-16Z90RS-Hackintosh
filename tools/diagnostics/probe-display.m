#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <VideoToolbox/VideoToolbox.h>
#import <dlfcn.h>
int main(void){ @autoreleasepool {
 [NSApplication sharedApplication];
 NSMutableDictionary *out=[NSMutableDictionary dictionary];
 out[@"HEVC_hardware_advertised"]=@(VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC));
 out[@"H264_hardware_advertised"]=@(VTIsHardwareDecodeSupported(kCMVideoCodecType_H264));
 out[@"time"]=[[NSDate date] description];
 NSMutableArray *screens=[NSMutableArray array];
 for(NSScreen *s in [NSScreen screens]) {
  CGDirectDisplayID did=[s.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
  NSMutableDictionary *r=[NSMutableDictionary dictionary];
  r[@"id"]=@(did);r[@"name"]=s.localizedName;r[@"builtIn"]=@(CGDisplayIsBuiltin(did));
  r[@"online"]=@(CGDisplayIsOnline(did)); r[@"active"]=@(CGDisplayIsActive(did));
  r[@"potentialEDR"]=@(s.maximumPotentialExtendedDynamicRangeColorComponentValue);
  r[@"currentEDR"]=@(s.maximumExtendedDynamicRangeColorComponentValue);
  r[@"referenceEDR"]=@(s.maximumReferenceExtendedDynamicRangeColorComponentValue);
  r[@"colorSpace"]=s.colorSpace.localizedName ?: @"";
  NSMutableArray *modes=[NSMutableArray array];
  NSDictionary *options=@{(__bridge NSString*)kCGDisplayShowDuplicateLowResolutionModes:@YES};
  CFArrayRef all=CGDisplayCopyAllDisplayModes(did,(__bridge CFDictionaryRef)options);
  CGDisplayModeRef current=CGDisplayCopyDisplayMode(did);
  if(current) {CFStringRef e=CGDisplayModeCopyPixelEncoding(current);
   r[@"currentMode"]=@{@"id":@(CGDisplayModeGetIODisplayModeID(current)),@"width":@(CGDisplayModeGetWidth(current)),@"height":@(CGDisplayModeGetHeight(current)),@"pixelWidth":@(CGDisplayModeGetPixelWidth(current)),@"pixelHeight":@(CGDisplayModeGetPixelHeight(current)),@"refresh":@(CGDisplayModeGetRefreshRate(current)),@"encoding":e?(__bridge NSString*)e:@""};
   if(e)CFRelease(e); CGDisplayModeRelease(current);
  }
  if(all) {for(CFIndex i=0;i<CFArrayGetCount(all);i++){
   CGDisplayModeRef m=(CGDisplayModeRef)CFArrayGetValueAtIndex(all,i);
   CFStringRef e=CGDisplayModeCopyPixelEncoding(m);
   [modes addObject:@{@"id":@(CGDisplayModeGetIODisplayModeID(m)),@"width":@(CGDisplayModeGetWidth(m)),@"height":@(CGDisplayModeGetHeight(m)),@"pixelWidth":@(CGDisplayModeGetPixelWidth(m)),@"pixelHeight":@(CGDisplayModeGetPixelHeight(m)),@"refresh":@(CGDisplayModeGetRefreshRate(m)),@"encoding":e?(__bridge NSString*)e:@""}];
   if(e)CFRelease(e);
  } CFRelease(all);}
  r[@"modes"]=modes;[screens addObject:r];
 }
 out[@"screens"]=screens;
 NSError *error=nil;NSData *d=[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:&error];
 if(!d){fprintf(stderr,"JSON error %s\n",error.description.UTF8String);return 1;}
 fwrite(d.bytes,1,d.length,stdout);fputs("\n",stdout);
 }return 0;
}
