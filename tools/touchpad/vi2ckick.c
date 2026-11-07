// vi2ckick: drive the local VoodooI2CHIDDevice test hooks.
//   vi2ckick kick 1|2          1 = HID SET_POWER(ON), 2 = HID reset
//   vi2ckick set <hex bytes>   write feature report, first byte = report ID (e.g. 0303, 0503)
//   vi2ckick get <id>          read feature report <id> (decimal), prints bytes
//   vi2ckick diag              print input/interrupt counters
//   Touchpad "dead" fix by hand: vi2ckick set 050300; vi2ckick set 030300
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void printResult(io_service_t s) {
    CFTypeRef r = IORegistryEntryCreateCFProperty(s, CFSTR("VoodooI2CKickResult"), NULL, 0);
    if (r && CFGetTypeID(r) == CFNumberGetTypeID()) {
        int v = 0; CFNumberGetValue((CFNumberRef)r, kCFNumberIntType, &v);
        printf("result=0x%x\n", v);
    }
    if (r) CFRelease(r);
}

int main(int argc, char **argv) {
    if (argc < 2 || (argc < 3 && strcmp(argv[1], "diag"))) { fprintf(stderr, "usage: %s kick N | set HEX | get ID | diag\n", argv[0]); return 2; }
    io_service_t s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("VoodooI2CHIDDevice"));
    if (!s) { fprintf(stderr, "VoodooI2CHIDDevice not found\n"); return 1; }
    kern_return_t kr = KERN_FAILURE;
    if (!strcmp(argv[1], "kick")) {
        int v = atoi(argv[2]);
        CFNumberRef n = CFNumberCreate(NULL, kCFNumberIntType, &v);
        kr = IORegistryEntrySetCFProperty(s, CFSTR("VoodooI2CKick"), n); CFRelease(n);
    } else if (!strcmp(argv[1], "set")) {
        size_t len = strlen(argv[2]) / 2; unsigned char buf[64];
        if (len < 2 || len > sizeof(buf)) { fprintf(stderr, "bad hex\n"); return 2; }
        for (size_t i = 0; i < len; i++) { unsigned x; sscanf(argv[2] + 2 * i, "%2x", &x); buf[i] = (unsigned char)x; }
        CFDataRef d = CFDataCreate(NULL, buf, (CFIndex)len);
        kr = IORegistryEntrySetCFProperty(s, CFSTR("VoodooI2CSetFeature"), d); CFRelease(d);
    } else if (!strcmp(argv[1], "diag")) {
        int v = 1;
        CFNumberRef n = CFNumberCreate(NULL, kCFNumberIntType, &v);
        kr = IORegistryEntrySetCFProperty(s, CFSTR("VoodooI2CDiag"), n); CFRelease(n);
        CFTypeRef p = IORegistryEntryCreateCFProperty(s, CFSTR("VoodooI2CDiagStats"), NULL, 0);
        char line[512] = "";
        if (p && CFGetTypeID(p) == CFStringGetTypeID()) CFStringGetCString((CFStringRef)p, line, sizeof(line), kCFStringEncodingUTF8);
        printf("%s\n", line);
        if (p) CFRelease(p);
        IOObjectRelease(s);
        return kr != KERN_SUCCESS;
    } else if (!strcmp(argv[1], "get")) {
        int v = atoi(argv[2]);
        CFNumberRef n = CFNumberCreate(NULL, kCFNumberIntType, &v);
        kr = IORegistryEntrySetCFProperty(s, CFSTR("VoodooI2CGetFeature"), n); CFRelease(n);
        CFTypeRef p = IORegistryEntryCreateCFProperty(s, CFSTR("VoodooI2CLastFeature"), NULL, 0);
        if (p && CFGetTypeID(p) == CFDataGetTypeID()) {
            const UInt8 *b = CFDataGetBytePtr((CFDataRef)p); CFIndex l = CFDataGetLength((CFDataRef)p);
            printf("feature %d:", v); for (CFIndex i = 0; i < l && i < 16; i++) printf(" %02x", b[i]); printf("\n");
        }
        if (p) CFRelease(p);
    }
    printf("kr=0x%x ", kr); printResult(s);
    IOObjectRelease(s);
    return kr != KERN_SUCCESS;
}
