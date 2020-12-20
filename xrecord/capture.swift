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
            let deviceManufacturer = device.manufacturer
            print("\(deviceID):\(deviceName):\(deviceManufacturer)")
        }
    }
}

func listDevices() {
    RunLoop.current.run(until: Date() + 1)

    let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.externalUnknown], mediaType: nil, position: AVCaptureDevice.Position.unspecified);

    RunLoop.current.run(until: Date() + 1)
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
            self.rawOutput.videoSettings = [:]
//            self.rawOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr8Planar]
//            self.rawOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_24RGB]
//            self.rawOutput.videoSettings = [
//                AVVideoCodecKey:AVVideoCodecType.h264,
//                AVVideoWidthKey:1088 / 2,
//                AVVideoHeightKey:1920 / 2,
//            ]
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
var frameCount = 0
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    do {
        if let ib = sampleBuffer.imageBuffer {
            let pb = ib as CVPixelBuffer
            CVPixelBufferLockBaseAddress(pb, CVPixelBufferLockFlags.readOnly)
            if let address = CVPixelBufferGetBaseAddress(pb) {
                let size = CVPixelBufferGetDataSize(pb)

                if (firstPacket) {
                    firstPacket = false
                    
                    if let fd = sampleBuffer.formatDescription {
                        let planeCount = CVPixelBufferGetPlaneCount(pb)
                        print("\(fd.dimensions.width),\(fd.dimensions.height),\(size),\(planeCount)")
                        for plane in 0..<planeCount {
                            let bpr = CVPixelBufferGetBytesPerRowOfPlane(pb, plane)
                            let pw = CVPixelBufferGetWidthOfPlane(pb, plane)
                            let ph = CVPixelBufferGetHeightOfPlane(pb, plane)
                            print("\(pw),\(ph),\(bpr)")
                        }

                        for ps in fd.parameterSets {
                            let header = Data.init([0, 0, 0, UInt8(ps.count)])
                            fileHandle.write(header)
                            fileHandle.write(ps)
                            fsync(fileHandle.fileDescriptor)
                        }
                    }
                }

                let y = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!
//                let u = CVPixelBufferGetBaseAddressOfPlane(pb, 1)!
//                let v = CVPixelBufferGetBaseAddressOfPlane(pb, 2)!

                // there's some padding.
                let d0 = address.distance(to: y)
//                let d1 = y.distance(to: u)
//                let d2 = u.distance(to: v)

                let length = CFSwapInt32HostToBig(UInt32(size - d0))
                withUnsafeBytes(of: length) {
                    write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: length))
                }
                write(fileHandle.fileDescriptor, y, size - d0)
//                print("frame \(frameCount)")
                frameCount += 1
                fsync(fileHandle.fileDescriptor)
            }
            CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags.readOnly)
        }
        else {
            if let db = try sampleBuffer.dataBuffer?.dataBytes() {
                if (firstPacket) {
                    firstPacket = false
                    if let fd = sampleBuffer.formatDescription {
                        print("\(fd.dimensions.width),\(fd.dimensions.height),0,0")
                    }
                    
                    for (ps) in sampleBuffer.formatDescription!.parameterSets {
//                        print(ps)

                        let length = CFSwapInt32HostToBig(UInt32(8 + 4 + ps.count))
                        withUnsafeBytes(of: length) {
                            write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: length))
                        }
                        
                        if let fd = sampleBuffer.formatDescription {
                            let width = CFSwapInt32HostToBig(UInt32(fd.dimensions.width))
                            let height = CFSwapInt32HostToBig(UInt32(fd.dimensions.height))

                            withUnsafeBytes(of: width) {
                                write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: width))
                            }
                            withUnsafeBytes(of: height) {
                                write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: height))
                            }
                        }

                        let avc0001 = CFSwapInt32HostToBig(1)
                        withUnsafeBytes(of: avc0001) {
                            write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: avc0001))
                        }
                        fileHandle.write(ps)
                    }
                }

//                var offset: Int = 0
//                while offset < db.count {
//                    let len: UInt = (UInt(db[offset]) << 24) | (UInt(db[offset + 1]) << 16) | (UInt(db[offset + 2]) << 8) | UInt(db[offset + 3]);
//                    // rewrites from avcc to annex b
////                    db[offset] = 0
////                    db[offset + 1] = 0
////                    db[offset + 2] = 0
////                    db[offset + 3] = 1
//                    offset += 4 + Int(len)
//                }
//                let size = sampleBuffer.dataBuffer?.dataLength

                
                let length = CFSwapInt32HostToBig(UInt32(8 + db.count))
                withUnsafeBytes(of: length) {
                    write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: length))
                }
                
                if let fd = sampleBuffer.formatDescription {
                    let width = CFSwapInt32HostToBig(UInt32(fd.dimensions.width))
                    let height = CFSwapInt32HostToBig(UInt32(fd.dimensions.height))

                    withUnsafeBytes(of: width) {
                        write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: width))
                    }
                    withUnsafeBytes(of: height) {
                        write(fileHandle.fileDescriptor, $0.baseAddress, MemoryLayout.size(ofValue: height))
                    }
                }
                    
                fileHandle.write(db)
                fsync(fileHandle.fileDescriptor)
            }
        }
    }
    catch {
    }
}

func fileOutput(_ output: AVCaptureFileOutput,
    didStartRecordingTo fileURL: URL,
    from connections: [AVCaptureConnection]) {
    self.started = true
}
func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    self.finished = true
}

} // class Capture
