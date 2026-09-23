//
//  CameraPreview.swift
//  AirCanvas
//
//  Created by Khush  on 22/09/26.
//

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable{
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView{
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = . resizeAspect
        view.layer.addSublayer(previewLayer)
        
        return view
        
        func updateUIView(_ uiView: UIView, context: Context){
            
        }
    }
}
