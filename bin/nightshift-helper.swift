#!/usr/bin/env swift
import Foundation
import ObjectiveC

// Load private framework
let handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
guard handle != nil,
      let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type else {
    fputs("error: cannot load CoreBrightness\n", stderr)
    exit(1)
}

let client = cls.init()

// Type aliases for objc_msgSend variants
typealias MsgSendBool = @convention(c) (AnyObject, Selector, Bool) -> Bool
typealias MsgSendFloatPtr = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<Float>) -> Bool
typealias MsgSendFloatBool = @convention(c) (AnyObject, Selector, Float, Bool) -> Bool
typealias MsgSendPtr = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool

// Status struct matching CBBlueLightStatus
struct CBStatus {
    var enabled: Bool = false
    var sunSchedulePermitted: Bool = false
    var available: Bool = false
    var active: Bool = false
    var mode: Int32 = 0
    var schedule: Int32 = 0
    var disableFlags: UInt64 = 0
    var availableOptions: UInt64 = 0
}

func isEnabled() -> Bool {
    var status = CBStatus()
    let sel = NSSelectorFromString("getBlueLightStatus:")
    let impl = class_getMethodImplementation(type(of: client), sel)
    let fn = unsafeBitCast(impl, to: MsgSendPtr.self)
    _ = withUnsafeMutablePointer(to: &status) { ptr in
        fn(client, sel, ptr)
    }
    return status.enabled
}

func setEnabled(_ on: Bool) {
    let sel = NSSelectorFromString("setEnabled:")
    let impl = class_getMethodImplementation(type(of: client), sel)
    let fn = unsafeBitCast(impl, to: MsgSendBool.self)
    _ = fn(client, sel, on)
}

func getStrength() -> Int {
    var strength: Float = 0
    let sel = NSSelectorFromString("getStrength:")
    let impl = class_getMethodImplementation(type(of: client), sel)
    let fn = unsafeBitCast(impl, to: MsgSendFloatPtr.self)
    _ = fn(client, sel, &strength)
    return Int(strength * 100)
}

func setStrength(_ percent: Int) {
    let value = Float(max(0, min(100, percent))) / 100.0
    let sel = NSSelectorFromString("setStrength:commit:")
    let impl = class_getMethodImplementation(type(of: client), sel)
    let fn = unsafeBitCast(impl, to: MsgSendFloatBool.self)
    _ = fn(client, sel, value, true)
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "status" {
case "on":     setEnabled(true);  print("on")
case "off":    setEnabled(false); print("off")
case "toggle": let on = !isEnabled(); setEnabled(on); print(on ? "on" : "off")
case "status": print(isEnabled() ? "on" : "off")
case "temp":
    if args.count > 2, let v = Int(args[2]), (0...100).contains(v) {
        setStrength(v); print(v)
    } else {
        print(getStrength())
    }
default: fputs("usage: nightshift-helper [on|off|toggle|status|temp [0-100]]\n", stderr); exit(1)
}
