//
//  capture.swift
//  xrecord
//
//  Created by Patrick Meenan on 2/26/15.
//  Copyright (c) 2015 WPO Foundation. All rights reserved.
//

import Foundation
import AVFoundation

class Capture: NSObject, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {

var session : AVCaptureSession!
var input : AVCaptureDeviceInput?
var output : AVCaptureMovieFileOutput!
var rawOutput: AVCaptureVideoDataOutput!
var started : Bool = false
var finished : Bool = false
var fileHandle: FileHandle!

override init() {
    self.session = AVCaptureSession()
    self.session.sessionPreset = AVCaptureSession.Preset.high

    // Enable screen capture devices in AV Foundation
    xRecord_Bridge.enableScreenCaptureDevices()
}

func pollDevices() {
    while true {
        RunLoop.current.run(until: Date() + 1)
        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.externalUnknown], mediaType: nil, position: AVCaptureDevice.Position.unspecified);

        print("---start")
        let devices = discoverySession.devices
        for object in devices {
            let device = object
            let deviceID = device.uniqueID
            let deviceName = device.localizedName
            print("\(deviceID): \(deviceName)")
        }
    }
}

func listDevices() {
    let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.externalUnknown], mediaType: nil, position: AVCaptureDevice.Position.unspecified);

    let devices = discoverySession.devices
    for object in devices {
        let device = object
        let deviceID = device.uniqueID
        let deviceName = device.localizedName
        print("\(deviceID): \(deviceName)")
    }
}
    
func getDevices() -> [AVCaptureDevice] {
    RunLoop.current.run(until: Date() + 1)

    let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.externalUnknown], mediaType: nil, position: AVCaptureDevice.Position.unspecified);
    
    RunLoop.current.run(until: Date() + 1)
    return discoverySession.devices
}

func setQuality(_ quality: String!) {
  if (quality == "low") {
    self.session.sessionPreset = AVCaptureSession.Preset.low;
  } else if (quality == "medium") {
    self.session.sessionPreset = AVCaptureSession.Preset.medium;
  } else if (quality == "high") {
    self.session.sessionPreset = AVCaptureSession.Preset.high;
  } else if (quality == "photo") {
    self.session.sessionPreset = AVCaptureSession.Preset.photo;
  }
}

func setDeviceByName(_ name: String!) -> Bool {
    var found : Bool = false
    let devices: NSArray = getDevices() as NSArray
    for object:AnyObject in devices as [AnyObject] {
        let captureDevice = object as! AVCaptureDevice
        if captureDevice.localizedName == name {
            var err : NSError? = nil
            do {
                self.input = try AVCaptureDeviceInput(device: captureDevice)
            } catch let error as NSError {
                err = error
                self.input = nil
            }
            if err == nil {
                found = true
            }
        }
    }
    return found
}
    
func setDeviceById(_ id: String!) -> Bool {
    var found : Bool = false
    let devices: NSArray = getDevices() as NSArray
    for object:AnyObject in devices as [AnyObject] {
        let captureDevice = object as! AVCaptureDevice
        if captureDevice.uniqueID == id {
            var err : NSError? = nil
            do {
                self.input = try AVCaptureDeviceInput(device: captureDevice)
            } catch let error as NSError {
                err = error
                self.input = nil
            }
            if err == nil {
                found = true
            }
        }
    }
    return found
}

func start(_ file: String!) -> Bool {
    var started : Bool = false
    if let input = self.input {
        if self.session.canAddInput(input) {
            self.session.addInput(input)
            self.output = AVCaptureMovieFileOutput()
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                self.session.startRunning()
                self.output.startRecording(to: URL(fileURLWithPath: file), recordingDelegate: self)
                started = true
            }
        }
    }
    return started
}

func startRaw(_ file: String!) -> Bool {
    var started : Bool = false
    if let input = self.input {
        if self.session.canAddInput(input) {
            self.session.addInput(input)
            let queue = DispatchQueue.init(label: "test")
            self.rawOutput = AVCaptureVideoDataOutput()
            self.rawOutput.setSampleBufferDelegate(self, queue: queue)
            self.rawOutput.videoSettings = [AVVideoCodecKey:AVVideoCodecType.h264]
//            self.rawOutput.videoSettings[AVVideoCodecKey] = AVVideoCodecType.h264
            FileManager.default.createFile(atPath: file, contents: nil);
            if let fh = FileHandle(forWritingAtPath: file) {
                fileHandle = fh
                if self.session.canAddOutput(self.rawOutput) {
                    self.session.addOutput(self.rawOutput)
                    self.session.startRunning()
                    started = true
                }
            }
        }
    }
    return started
}

func stop() {
    self.output?.stopRecording()
    self.session.stopRunning()
    fileHandle?.closeFile()
}

func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
}

var firstPacket = true
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    if (firstPacket) {
        firstPacket = false
        
        if let parm = sampleBuffer.formatDescription?.parameterSets  {
            for ps in parm {
                let header = Data.init([0,0,0,1])
                fileHandle.write(header)
                fileHandle.write(ps)
            }
        }
    }
    
    do {
        if var db = try sampleBuffer.dataBuffer?.dataBytes() {
            var offset: Int = 0
            while offset < db.count {
                let len: UInt = (UInt(db[offset]) << 24) | (UInt(db[offset + 1]) << 16) | (UInt(db[offset + 2]) << 8) | UInt(db[offset + 3]);
                db[offset] = 0
                db[offset + 1] = 0
                db[offset + 2] = 0
                db[offset + 3] = 1
                offset += 4 + Int(len)
            }
            fileHandle.write(db)
        }
    }
    catch {
    }
}

func fileOutput(_ output: AVCaptureFileOutput,
    didStartRecordingTo fileURL: URL,
    from connections: [AVCaptureConnection]) {
   NSLog("captureOutput Started callback");
   self.started = true
}
func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    NSLog("captureOutput Finished callback")
    self.finished = true
}

} // class Capture
