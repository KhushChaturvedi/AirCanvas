//
//  ContentView.swift
//  AirCanvas
//
//  Created by Khush  on 21/09/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var handTracker = HandTracker()
    @StateObject private var drawingCanvas = DrawingCanvas()

    @State private var canvasSize: CGSize = .zero
    @State private var selectedColor: Color = .green

    let palette: [Color] = [.green, .red, .blue, .yellow, .purple, .white]

    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<drawingCanvas.completedStrokes.count, id: \.self) { strokeIndex in
                        let stroke = drawingCanvas.completedStrokes[strokeIndex]
                        neonStroke(stroke.points, color: stroke.color, size: geometry.size, smooth: false)
                    }

                    neonStroke(drawingCanvas.currentStroke, color: selectedColor, size: geometry.size, smooth: true)
                }
                .onAppear {
                    canvasSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newSize in
                    canvasSize = newSize
                }
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()
                HStack(spacing: 16) {
                    ForEach(palette, id: \.self) { color in
                        colorCircle(color)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            cameraManager.handTracker = handTracker
            drawingCanvas.currentColor = selectedColor
            cameraManager.start()
        }
        .onChange(of: handTracker.isPinching) { _, isPinching in
            if !isPinching {
                drawingCanvas.endStroke(size: canvasSize)
            }
        }
        .onChange(of: handTracker.indexTip) { _, newIndexTip in
            if handTracker.isPinching, let tip = newIndexTip {
                drawingCanvas.addPoint(tip)
            }
        }
        .onChange(of: handTracker.isOpenPalm) { _, isOpen in
            if isOpen {
                drawingCanvas.clear()
            }
        }
    }

    func colorCircle(_ color: Color) -> some View {
        let isSelected = selectedColor == color
        let ringWidth: CGFloat = isSelected ? 3 : 0

        return Circle()
            .fill(color)
            .frame(width: 36, height: 36)
            .overlay(
                Circle().stroke(Color.white, lineWidth: ringWidth)
            )
            .onTapGesture {
                selectedColor = color
                drawingCanvas.currentColor = color
            }
    }

    @ViewBuilder
    func neonStroke(_ stroke: [CGPoint], color: Color, size: CGSize, smooth: Bool) -> some View {
        Path { path in
            drawStroke(stroke, in: &path, size: size, smooth: smooth)
        }
        .stroke(color, lineWidth: 10)
        .blur(radius: 12)
        .opacity(0.8)

        Path { path in
            drawStroke(stroke, in: &path, size: size, smooth: smooth)
        }
        .stroke(color, lineWidth: 5)
        .blur(radius: 4)

        Path { path in
            drawStroke(stroke, in: &path, size: size, smooth: smooth)
        }
        .stroke(Color.white, lineWidth: 2)
    }

    func drawStroke(_ stroke: [CGPoint], in path: inout Path, size: CGSize, smooth: Bool) {
        guard let first = stroke.first else {
            return
        }

        let points = stroke.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

        path.move(to: points[0])

        if !smooth || points.count < 3 {
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return
        }

        for i in 1..<points.count - 1 {
            let midPoint = CGPoint(
                x: (points[i].x + points[i + 1].x) / 2,
                y: (points[i].y + points[i + 1].y) / 2
            )
            path.addQuadCurve(to: midPoint, control: points[i])
        }
    }
}

#Preview {
    ContentView()
}n
