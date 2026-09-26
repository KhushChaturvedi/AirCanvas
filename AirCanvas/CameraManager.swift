//
//  CameraManager.swift
//  AirCanvas
//
//  Created by Khush  on 22/09/26.
//

import AVFoundation
import Combine

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate{
    let session = AVCaptureSession()
    var handTracker: HandTracker?
    
    func start(){
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,  for: .video ,position: .front) else {return }
        
        guard let input = try? AVCaptureDeviceInput(device: device) else {return}
        
        if session.canAddInput(input){
            session.addInput(input)
    }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput){
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async{
            self.session.startRunning()
        }
  }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else{
            return
        }
        
        handTracker?.findHand(in: pixelBuffer)
    }
}
