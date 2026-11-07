// lggram-audiod: speaker support for LG gram Style (ALC298 + 4 smart amps) on macOS.
// - Ports Linux ALC298_FIXUP_LG_GRAM_STYLE_14 (sound/hda/codecs/realtek/alc269.c):
//   amps are initialised once, enabled while playback runs, disabled when it stops.
// - AppleALC layout 3 only drives speaker pin 0x14; this machine also needs pin 0x17
//   (second internal speaker pin, assoc 1) routed to mixer 0x0d.
// - Re-initialises after wake. Talks to AppleALC's ALCUserClientProvider (needs alcverbs=1).
import Foundation
import IOKit
import IOKit.pwr_mgt
import CoreAudio

setvbuf(stdout, nil, _IOLBF, 0)
let stamp = DateFormatter(); stamp.dateFormat = "yyyy-MM-dd HH:mm:ss"
func log(_ s: String) { print("\(stamp.string(from: Date())) \(s)") }

final class Codec {
    private var conn: io_connect_t = 0
    func open() -> Bool {
        if conn != 0 { return true }
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("ALCUserClientProvider"))
        if svc == 0 { return false }
        defer { IOObjectRelease(svc) }
        var c: io_connect_t = 0
        let kr = IOServiceOpen(svc, mach_task_self_, 0, &c)
        if kr != KERN_SUCCESS { log("IOServiceOpen failed 0x\(String(kr, radix: 16))"); return false }
        conn = c
        return true
    }
    func close() { if conn != 0 { IOServiceClose(conn); conn = 0 } }
    // Same verb conversion as AppleALC alc-verb: 4-bit verbs 0xn00 are passed as 0xn.
    @discardableResult func verb(_ nid: UInt64, _ v: UInt64, _ p: UInt64) -> Bool {
        guard open() else { return false }
        var input: [UInt64] = [nid, (v & 0xff) != 0 ? v : (v >> 8), p]
        var out: UInt64 = 0
        var cnt: UInt32 = 1
        let kr = IOConnectCallScalarMethod(conn, 0, &input, 3, &out, &cnt)
        if kr != KERN_SUCCESS {
            log("verb nid=0x\(String(nid, radix: 16)) verb=0x\(String(v, radix: 16)) failed 0x\(String(kr, radix: 16))")
            close()
            return false
        }
        return true
    }
}

let codec = Codec()
let q = DispatchQueue(label: "lggram-audiod")

func coef(_ idx: UInt64, _ val: UInt64) -> Bool {
    codec.verb(0x20, 0x500, idx) && codec.verb(0x20, 0x400, val)
}
func cw(_ v: UInt64, _ idx: UInt64, _ val: UInt64) -> Bool {
    codec.verb(0x20, 0x500, 0x23) && codec.verb(0x20, v, idx) && codec.verb(0x20, 0x400, 0x00) &&
        codec.verb(0x20, 0x400, val) && codec.verb(0x20, 0x400, 0xb011)
}
func run(_ seq: [UInt64]) -> Bool {
    var i = 0
    while i + 2 < seq.count { if !cw(seq[i], seq[i + 1], seq[i + 2]) { return false }; i += 3 }
    return true
}

let seqA: [UInt64] = [0x423, 0xe1, 0x00, 0x420, 0x12, 0x6f, 0x420, 0x14, 0x00, 0x420, 0x1b, 0x01, 0x420, 0x1d, 0x01,
    0x420, 0x1f, 0xfe, 0x420, 0x21, 0x00, 0x420, 0x22, 0x10, 0x420, 0x3d, 0x05, 0x420, 0x3f, 0x03,
    0x420, 0x50, 0x2c, 0x420, 0x76, 0x0e, 0x420, 0x7c, 0x4a, 0x420, 0x81, 0x03]
let seqB: [UInt64] = [0x423, 0xe1, 0x00, 0x420, 0x12, 0x6f, 0x420, 0x14, 0x00, 0x420, 0x1b, 0x02, 0x420, 0x1d, 0x02,
    0x420, 0x1f, 0xfd, 0x420, 0x21, 0x01, 0x420, 0x22, 0x10, 0x420, 0x3d, 0x05, 0x420, 0x3f, 0x03,
    0x420, 0x50, 0x2c, 0x420, 0x76, 0x0e, 0x420, 0x7c, 0x4a, 0x420, 0x81, 0x03]
let tail38: [UInt64] = [0x423, 0x99, 0x03, 0x423, 0xa4, 0xb5, 0x423, 0xa5, 0x01, 0x423, 0xba, 0x94]
let tail3c: [UInt64] = [0x423, 0xba, 0x8d]
let amps: [(UInt64, [UInt64])] = [(0x38, seqA + tail38), (0x39, seqB + tail38), (0x3c, seqA + tail3c), (0x3d, seqB + tail3c)]

func ampsInit() -> Bool {
    for (nid, seq) in amps {
        guard coef(0x22, nid), cw(0x420, 0x00, 0x01), cw(0x423, 0xff, 0x00), cw(0x420, 0x3a, 0x80),
              run(seq), coef(0x89, 0x0) else { return false }
    }
    return true
}
func ampsEnable() -> Bool {
    for (nid, _) in amps { guard coef(0x22, nid), cw(0x420, 0x3a, 0x81), cw(0x423, 0xff, 0x01) else { return false } }
    return true
}
func ampsDisable() -> Bool {
    for (nid, _) in amps { guard coef(0x22, nid), cw(0x423, 0xff, 0x00), cw(0x420, 0x3a, 0x80) else { return false } }
    return true
}
// Pin 0x17: D0, connection index 1 (mixer 0x0d, fed by the active DAC 0x03), output, EAPD, unmute.
func pin17() -> Bool {
    codec.verb(0x17, 0x705, 0x00) && codec.verb(0x17, 0x701, 0x01) && codec.verb(0x17, 0x707, 0x40) &&
        codec.verb(0x17, 0x70c, 0x02) && codec.verb(0x17, 0x300, 0xb000)
}

// CoreAudio: watch the built-in output device.
func addr(_ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
    -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}
func u32(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> UInt32? {
    var a = addr(sel, scope)
    var v: UInt32 = 0
    var s = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(id, &a, 0, nil, &s, &v) == noErr ? v : nil
}
func builtinOutput() -> AudioObjectID? {
    var a = addr(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    let sys = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr, size > 0 else { return nil }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return nil }
    for id in ids where u32(id, kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal) == kAudioDeviceTransportTypeBuiltIn {
        var sa = addr(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var ss: UInt32 = 0
        if AudioObjectGetPropertyDataSize(id, &sa, 0, nil, &ss) == noErr, ss > 0 { return id }
    }
    return nil
}

let headphones: UInt32 = 0x6864706e // 'hdpn'
var device: AudioObjectID = 0
var initialised = false
var ampsOn = false
var offGeneration = 0

func ensureInit() -> Bool {
    if initialised { return true }
    guard codec.open() else { return false }
    if ampsInit() { initialised = true; ampsOn = false; log("amps initialised") } else { log("amp init failed") }
    return initialised
}

func update(_ why: String) {
    guard device != 0, ensureInit() else { return }
    let running = (u32(device, kAudioDevicePropertyDeviceIsRunningSomewhere, kAudioObjectPropertyScopeGlobal) ?? 0) != 0
    let source = u32(device, kAudioDevicePropertyDataSource, kAudioObjectPropertyScopeOutput) ?? 0
    let want = running && source != headphones
    if want {
        let p = pin17()
        if !ampsOn { ampsOn = ampsEnable() }
        log("\(why): running source=\(String(format: "%08x", source)) pin17=\(p) amps=\(ampsOn)")
        offGeneration += 1
    } else if ampsOn {
        // Headphones: off now. Stopped: keep the amps up for 60 s so short sounds
        // (alerts, clicks) that start before we react are not clipped.
        offGeneration += 1
        let gen = offGeneration
        let delay: Double = source == headphones ? 0 : 60
        q.asyncAfter(deadline: .now() + delay) {
            guard gen == offGeneration, ampsOn else { return }
            ampsOn = !ampsDisable()
            log("\(why): stopped/headphones running=\(running) source=\(String(format: "%08x", source)) amps=\(ampsOn)")
        }
    }
}

var listened: AudioObjectID = 0
func attach() {
    guard let id = builtinOutput() else { return }
    device = id
    if listened == id { return }
    for (sel, scope) in [(kAudioDevicePropertyDeviceIsRunningSomewhere, kAudioObjectPropertyScopeGlobal),
                         (kAudioDevicePropertyDataSource, kAudioObjectPropertyScopeOutput)] {
        var a = addr(sel, scope)
        let st = AudioObjectAddPropertyListenerBlock(id, &a, q) { _, _ in update("change") }
        if st != noErr { log("listener \(sel) failed \(st)") }
    }
    listened = id
    log("watching built-in output device \(id)")
}

// Power: re-initialise the amps after wake.
var rootPort: io_connect_t = 0
var notifyPort: IONotificationPortRef?
var notifier: io_object_t = 0
let powerCallback: IOServiceInterestCallback = { _, _, messageType, argument in
    // iokit_common_msg(0x270/0x280/0x300); the macros are not imported into Swift.
    switch messageType {
    case 0xE000_0270, 0xE000_0280: // CanSystemSleep, SystemWillSleep
        IOAllowPowerChange(rootPort, Int(bitPattern: argument))
    case 0xE000_0300: // SystemHasPoweredOn
        q.asyncAfter(deadline: .now() + 3) {
            log("wake: re-initialising")
            codec.close(); initialised = false; ampsOn = false
            attach(); update("wake")
        }
    default: break
    }
}
rootPort = IORegisterForSystemPower(nil, &notifyPort, powerCallback, &notifier)
if rootPort != 0, let np = notifyPort {
    CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(np).takeUnretainedValue(), .defaultMode)
} else { log("IORegisterForSystemPower failed") }

var devAddr = addr(kAudioHardwarePropertyDevices)
AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddr, q) { _, _ in attach(); update("devices") }

// Startup: wait for AppleALC and the built-in device, then initialise.
func startup() {
    attach()
    if device != 0 && ensureInit() { update("startup"); return }
    q.asyncAfter(deadline: .now() + 2) { startup() }
}
log("lggram-audiod starting")
q.async { startup() }
// Safety net: re-apply the running state every 30 s (cheap when nothing changed).
let timer = DispatchSource.makeTimerSource(queue: q)
timer.schedule(deadline: .now() + 30, repeating: 30)
timer.setEventHandler { if device != 0 && initialised { update("tick") } }
timer.resume()
CFRunLoopRun()
