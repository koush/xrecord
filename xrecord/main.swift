//
//  main.swift
//  xrecord
//
//  Created by Patrick Meenan on 12/10/15.
//  Copyright (c) 2015 WPO Foundation. All rights reserved.
//

import Foundation
import AVFoundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

let xRecord_Bridge: XRecord_Bridge = XRecord_Bridge();

func quit(_ exitCode: Int32!) {
    xRecord_Bridge.stopScreenCapturePlugin();
  exit(exitCode);
}

let cli = CommandLine()

let silent = BoolOption(shortFlag: "s", longFlag: "silent",
    helpMessage: "Silent output.")
let list = BoolOption(shortFlag: "l", longFlag: "list",
    helpMessage: "List available capture devices.")
let poll = BoolOption(shortFlag: "p", longFlag: "poll",
    helpMessage: "Poll available capture devices.")
let execute = BoolOption(shortFlag: "e", longFlag: "exec",
    helpMessage: "Execute without signal handler.")
let name = StringOption(shortFlag: "n", longFlag: "name", required: false,
    helpMessage: "Device Name.")
let id = StringOption(shortFlag: "i", longFlag: "id", required: false,
    helpMessage: "Device ID.")
let outFile = StringOption(shortFlag: "o", longFlag: "out", required: false,
    helpMessage: "Output File.")
let raw = BoolOption(shortFlag: "r", longFlag: "raw",
    helpMessage: "Raw Output.")
let force = BoolOption(shortFlag: "f", longFlag: "force",
    helpMessage: "Overwrite existing files.")
let qt = BoolOption(shortFlag: "q", longFlag: "quicktime",
    helpMessage: "Include QuickTime devices (necessary for iOS recording).")
let time = IntOption(shortFlag: "t", longFlag: "time", required: false,
    helpMessage: "Recording time in seconds (records until stopped if not specified).")
let quality = StringOption(shortFlag: "u", longFlag: "quality", required: false,
  helpMessage: "Recording quality (low, medium, high, photo - defaults to high)")
let debug = BoolOption(shortFlag: "d", longFlag: "debug",
    helpMessage: "Display debugging info to stderr.")
let help = BoolOption(shortFlag: "h", longFlag: "help",
    helpMessage: "Prints a help message.")

setbuf(__stdoutp, nil);

cli.addOptions(silent, poll, list, execute, name, id, outFile, raw, force, qt, time, quality, debug, help)
let (success, error) = cli.parse()
if !success {
  print(error!)
  cli.printUsage()
  quit(EX_USAGE)
}

func sprint(_ s: String) {
    if (!silent.value) {
        print(s)
    }
}

// Check to make sure a sane combination of options were specified
var ok = true
if !list.value && !poll.value {
  if name.value == nil && id.value == nil {
    ok = false
  }
  if outFile.value == nil {
    ok = false
  }
}
if !ok {
  cli.printUsage()
  quit(EX_USAGE)
}

// If we were not launched with the debug flag, re-spawn and suppress stderr
if !debug.value {
  let proc = Process()
  var args = Swift.CommandLine.arguments
  proc.launchPath = args[0]
  args.append("--debug")
  proc.arguments = args
  proc.standardError = Pipe()
  proc.launch()
  xRecord_Bridge.installSignalHandler(proc.processIdentifier)
  proc.waitUntilExit()
  quit(proc.terminationStatus)
}

if (!execute.value) {
    xRecord_Bridge.installSignalHandler(0)
}

// Use a distributed lock to make sure only one instance is capturing at a time.
// Currently OSX only supports recording from a single device at a time.
var done = false
var started_wait = false
let lock_start = Date()


// See if we need to launch quicktime in the background
if qt.value {
    xRecord_Bridge.startScreenCapturePlugin();
}

let capture = Capture()
if (poll.value) {
    capture.pollDevices()
    quit(0)
}
if list.value {
  sprint("Available capture devices:")
  capture.listDevices()
  quit(0)
}

// Set up the input device
if quality.value != nil {
  capture.setQuality(quality.value);
}

var connected = false
if id.value != nil {
  if capture.setDeviceById(id.value) {
    connected = true
  }
}
if name.value != nil {
  if capture.setDeviceByName(name.value) {
    connected = true
  }
}
if !connected {
  sprint("Device not found")
  // kill quicktime in case it got wedged
  quit(1)
}

// See if a video file already exists in the given location
if outFile.value != nil && FileManager.default.fileExists(atPath: outFile.value!) {
  if force.value {
    var error:NSError?
    do {
      try FileManager.default.removeItem(atPath: outFile.value!)
    } catch var error1 as NSError {
      error = error1
    }
    if (error != nil) {
      sprint("Error overwriting existing file (\(error)). Continuing...")
    }
  } else {
    sprint("The output file already exists, please use a different file: \(outFile.value!)")
    quit(2)
  }
}

// Start a real capture
if !done {
  if raw.value {
     capture.startRaw(outFile.value)
  }
  else {
     capture.start(outFile.value)
  }

  let start = Date()
  if time.value != nil && time.value > 0 {
      sprint("Recording for \(time.value!) seconds.  Hit ctrl-C to stop.")
      sleep(UInt32(time.value!))
  } else {
      sprint("Recording started.  Hit ctrl-C to stop.")
  }

  // Loop until we get a ctrl-C or the time limit expires
  repeat {
      usleep(100)
      if xRecord_Bridge.didSignal() {
          done = true
      } else if time.value != nil && time.value > 0 {
          let now = Date()
          let elapsed: Double = now.timeIntervalSince(start)
          if elapsed >= Double(time.value!) {
              done = true
          }
      }
  } while !done

  sprint("Stopping recording...")

  capture.stop()
  if qt.value {
    xRecord_Bridge.stopScreenCapturePlugin();
  }
}

sprint("Done")

quit(0);
