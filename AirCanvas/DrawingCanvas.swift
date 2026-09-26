//
//  DrawingCanvas.swift
//  AirCanvas
//
//  Created by Khush  on 23/09/26.
//

import SwiftUI
import Combine

struct Stroke {
    var points: [CGPoint]
    var color: Color
}

class DrawingCanvas: ObservableObject {
    @Published var currentStroke: [CGPoint] = []
    @Published var completedStrokes: [Stroke] = []
    var currentColor: Color = .green

    func addPoint(_ point: CGPoint) {
        if let last = currentStroke.last {
            let distance = sqrt(pow(point.x - last.x, 2) + pow(point.y - last.y, 2))
            if distance < 0.006 {
                return
            }
        }
        currentStroke.append(point)
    }

    func endStroke(size: CGSize) {
        if !currentStroke.isEmpty {
            let snapped = snapShape(currentStroke, size: size)
            completedStrokes.append(Stroke(points: snapped, color: currentColor))
            currentStroke = []
        }
    }

    func undo() {
        if !completedStrokes.isEmpty {
            completedStrokes.removeLast()
        }
    }

    func clear() {
        completedStrokes = []
        currentStroke = []
    }

    // MARK: - Shape snapping

    func snapShape(_ stroke: [CGPoint], size: CGSize) -> [CGPoint] {
        guard stroke.count > 5 else {
            return stroke
        }

        let pixelStroke = stroke.map { toPixel($0, size: size) }

        if let line = detectLine(pixelStroke) {
            return line.map { toPercent($0, size: size) }
        }

        if let triangle = detectTriangle(pixelStroke) {
            return triangle.map { toPercent($0, size: size) }
        }

        if let rectangle = detectRectangle(pixelStroke) {
            return rectangle.map { toPercent($0, size: size) }
        }

        if let circle = detectCircle(pixelStroke) {
            return circle.map { toPercent($0, size: size) }
        }

        return stroke
    }

    private func toPixel(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func toPercent(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x / size.width, y: point.y / size.height)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2))
    }

    // MARK: - Line

    func detectLine(_ stroke: [CGPoint]) -> [CGPoint]? {
        guard let first = stroke.first, let last = stroke.last else {
            return nil
        }

        let straightDistance = distance(first, last)

        var pathLength: CGFloat = 0
        for i in 1..<stroke.count {
            pathLength += distance(stroke[i - 1], stroke[i])
        }

        guard pathLength > 0 else {
            return nil
        }

        let straightness = straightDistance / pathLength

        if straightness > 0.92 {
            return [first, last]
        }

        return nil
    }

    // MARK: - Circle

    func detectCircle(_ stroke: [CGPoint]) -> [CGPoint]? {
        guard let first = stroke.first, let last = stroke.last else {
            return nil
        }

        let minX = stroke.map { $0.x }.min() ?? 0
        let maxX = stroke.map { $0.x }.max() ?? 0
        let minY = stroke.map { $0.y }.min() ?? 0
        let maxY = stroke.map { $0.y }.max() ?? 0
        let boxSize = max(maxX - minX, maxY - minY)

        let closingDistance = distance(first, last)
        guard closingDistance < boxSize * 0.25 else {
            return nil
        }

        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for point in stroke {
            sumX += point.x
            sumY += point.y
        }
        let center = CGPoint(x: sumX / CGFloat(stroke.count), y: sumY / CGFloat(stroke.count))

        var radii: [CGFloat] = []
        for point in stroke {
            radii.append(distance(point, center))
        }

        let averageRadius = radii.reduce(0, +) / CGFloat(radii.count)

        var variance: CGFloat = 0
        for r in radii {
            variance += pow(r - averageRadius, 2)
        }
        variance = variance / CGFloat(radii.count)
        let standardDeviation = sqrt(variance)

        guard standardDeviation < averageRadius * 0.25 else {
            return nil
        }

        var circlePoints: [CGPoint] = []
        let segments = 60
        for i in 0...segments {
            let angle = (CGFloat(i) / CGFloat(segments)) * 2 * .pi
            let x = center.x + averageRadius * cos(angle)
            let y = center.y + averageRadius * sin(angle)
            circlePoints.append(CGPoint(x: x, y: y))
        }

        return circlePoints
    }

    // MARK: - Rectangle / Square

    func detectRectangle(_ stroke: [CGPoint]) -> [CGPoint]? {
        guard let first = stroke.first, let last = stroke.last else {
            return nil
        }

        let minX = stroke.map { $0.x }.min() ?? 0
        let maxX = stroke.map { $0.x }.max() ?? 0
        let minY = stroke.map { $0.y }.min() ?? 0
        let maxY = stroke.map { $0.y }.max() ?? 0

        let width = maxX - minX
        let height = maxY - minY
        let boxSize = max(width, height)

        guard width > 0, height > 0 else {
            return nil
        }

        let closingDistance = distance(first, last)
        guard closingDistance < boxSize * 0.25 else {
            return nil
        }

        var totalDeviation: CGFloat = 0
        for point in stroke {
            let distToLeft = abs(point.x - minX)
            let distToRight = abs(point.x - maxX)
            let distToTop = abs(point.y - minY)
            let distToBottom = abs(point.y - maxY)
            let nearestEdge = min(distToLeft, distToRight, distToTop, distToBottom)
            totalDeviation += nearestEdge
        }
        let averageDeviation = totalDeviation / CGFloat(stroke.count)

        guard averageDeviation < boxSize * 0.12 else {
            return nil
        }

        let topLeft = CGPoint(x: minX, y: minY)
        let topRight = CGPoint(x: maxX, y: minY)
        let bottomRight = CGPoint(x: maxX, y: maxY)
        let bottomLeft = CGPoint(x: minX, y: maxY)

        return [topLeft, topRight, bottomRight, bottomLeft, topLeft]
    }

    // MARK: - Triangle

    func detectTriangle(_ stroke: [CGPoint]) -> [CGPoint]? {
        guard let first = stroke.first, let last = stroke.last else {
            return nil
        }

        let minX = stroke.map { $0.x }.min() ?? 0
        let maxX = stroke.map { $0.x }.max() ?? 0
        let minY = stroke.map { $0.y }.min() ?? 0
        let maxY = stroke.map { $0.y }.max() ?? 0
        let boxSize = max(maxX - minX, maxY - minY)

        let closingDistance = distance(first, last)
        guard closingDistance < boxSize * 0.25 else {
            return nil
        }

        guard let corners = findCorners(stroke, count: 3) else {
            return nil
        }

        var totalDeviation: CGFloat = 0
        for point in stroke {
            let d1 = distanceToSegment(point, corners[0], corners[1])
            let d2 = distanceToSegment(point, corners[1], corners[2])
            let d3 = distanceToSegment(point, corners[2], corners[0])
            totalDeviation += min(d1, d2, d3)
        }
        let averageDeviation = totalDeviation / CGFloat(stroke.count)

        guard averageDeviation < boxSize * 0.12 else {
            return nil
        }

        return [corners[0], corners[1], corners[2], corners[0]]
    }

    private func findCorners(_ stroke: [CGPoint], count: Int) -> [CGPoint]? {
        guard stroke.count > count else {
            return nil
        }

        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for point in stroke {
            sumX += point.x
            sumY += point.y
        }
        let center = CGPoint(x: sumX / CGFloat(stroke.count), y: sumY / CGFloat(stroke.count))

        let farthestFirst = stroke.sorted {
            distance($0, center) > distance($1, center)
        }

        var corners: [CGPoint] = []
        let minGap = boundingDiagonal(stroke) * 0.2

        for candidate in farthestFirst {
            let tooClose = corners.contains { existing in
                distance(existing, candidate) < minGap
            }
            if !tooClose {
                corners.append(candidate)
            }
            if corners.count == count {
                break
            }
        }

        guard corners.count == count else {
            return nil
        }

        return sortClockwise(corners, around: center)
    }

    private func boundingDiagonal(_ stroke: [CGPoint]) -> CGFloat {
        let minX = stroke.map { $0.x }.min() ?? 0
        let maxX = stroke.map { $0.x }.max() ?? 0
        let minY = stroke.map { $0.y }.min() ?? 0
        let maxY = stroke.map { $0.y }.max() ?? 0
        return distance(CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: maxY))
    }

    private func sortClockwise(_ points: [CGPoint], around center: CGPoint) -> [CGPoint] {
        points.sorted { a, b in
            let angleA = atan2(a.y - center.y, a.x - center.x)
            let angleB = atan2(b.y - center.y, b.x - center.x)
            return angleA < angleB
        }
    }

    private func distanceToSegment(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return distance(point, a)
        }

        var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared
        t = max(0, min(1, t))

        let projection = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return distance(point, projection)
    }
}
