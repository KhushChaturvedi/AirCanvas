//
//  HandTracker.swift
//  AirCanvas
//
//  Created by Khush  on 23/09/26.
//

import Vision
import Combine

class HandTracker: ObservableObject {
    @Published var points: [CGPoint] = []
    @Published var thumbTip: CGPoint?
    @Published var indexTip: CGPoint?
    @Published var isPinching: Bool = false
    @Published var isOpenPalm: Bool = false

    private var missedPinchFrames: Int = 0
    private var openPalmFrames: Int = 0
    private var smoothedIndexTip: CGPoint?

    func findHand(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectHumanHandPoseRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)

        try? handler.perform([request])

        guard let result = request.results?.first else {
            missedPinchFrames += 1
            openPalmFrames = 0
            return
        }

        guard let allPoints = try? result.recognizedPoints(.all) else {
            return
        }

        var newPoints: [CGPoint] = []
        var newThumbTip: CGPoint?
        var newIndexTip: CGPoint?

        for (key, point) in allPoints {
            if point.confidence > 0.3 {
                let converted = CGPoint(x: point.location.x, y: 1 - point.location.y)
                newPoints.append(converted)

                if key == .thumbTip {
                    newThumbTip = converted
                }

                if key == .indexTip {
                    newIndexTip = converted
                }
            }
        }

        var rawPinching = false

        if let thumb = newThumbTip, let index = newIndexTip {
            let pinchDistance = sqrt(pow(thumb.x - index.x, 2) + pow(thumb.y - index.y, 2))
            if pinchDistance < 0.06 {
                rawPinching = true
            }
        }

        if rawPinching {
            missedPinchFrames = 0
        } else {
            missedPinchFrames += 1
        }

        let pinching = missedPinchFrames < 3

        var rawOpenPalm = false

        if !pinching, let wrist = allPoints[.wrist], wrist.confidence > 0.3 {
            let wristPoint = CGPoint(x: wrist.location.x, y: 1 - wrist.location.y)

            let tipKeys: [VNHumanHandPoseObservation.JointName] = [.thumbTip, .indexTip, .middleTip, .ringTip, .littleTip]

            var spreadDistances: [CGFloat] = []
            for key in tipKeys {
                if let tip = allPoints[key], tip.confidence > 0.3 {
                    let tipPoint = CGPoint(x: tip.location.x, y: 1 - tip.location.y)
                    let d = sqrt(pow(tipPoint.x - wristPoint.x, 2) + pow(tipPoint.y - wristPoint.y, 2))
                    spreadDistances.append(d)
                }
            }

            if spreadDistances.count == 5 {
                let averageSpread = spreadDistances.reduce(0, +) / CGFloat(spreadDistances.count)
                if averageSpread > 0.34 {
                    rawOpenPalm = true
                }
            }
        }

        if rawOpenPalm {
            openPalmFrames += 1
        } else {
            openPalmFrames = 0
        }

        let openPalm = openPalmFrames > 30

        if let raw = newIndexTip {
            if let previous = smoothedIndexTip {
                smoothedIndexTip = CGPoint(
                    x: previous.x * 0.5 + raw.x * 0.5,
                    y: previous.y * 0.5 + raw.y * 0.5
                )
            } else {
                smoothedIndexTip = raw
            }
        } else {
            smoothedIndexTip = nil
        }

        let finalIndexTip = smoothedIndexTip

        DispatchQueue.main.async {
            self.points = newPoints
            self.thumbTip = newThumbTip
            self.indexTip = finalIndexTip
            self.isPinching = pinching
            self.isOpenPalm = openPalm
        }
    }
}
