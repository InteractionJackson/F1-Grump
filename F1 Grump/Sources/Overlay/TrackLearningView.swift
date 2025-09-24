// README: TrackLearningView
// A dedicated view for learning and managing track outlines.
// Allows recording clean laps to create perfect track templates.

import SwiftUI

struct TrackLearningView: View {
    @ObservedObject var telemetryReceiver: TelemetryReceiver
    @State private var isRecording = false
    @State private var recordedPoints: [CGPoint] = []
    @State private var showSaveDialog = false
    @State private var lastUpdateTime: Date?
    
    init(telemetryReceiver: TelemetryReceiver) {
        self.telemetryReceiver = telemetryReceiver
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Track Learning")
                .font(.title2)
                .fontWeight(.bold)
            
            if telemetryReceiver.trackName.isEmpty {
                Text("No track detected")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 12) {
                    Text("Current Track: \(telemetryReceiver.trackName)")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        Button(action: startRecording) {
                            HStack {
                                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                                Text(isRecording ? "Stop Recording" : "Start Recording")
                            }
                            .foregroundColor(isRecording ? .red : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .disabled(telemetryReceiver.trackName.isEmpty)
                        
                        if !recordedPoints.isEmpty {
                            Button("Save Track") {
                                showSaveDialog = true
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                        
                        if telemetryReceiver.hasLearnedTrack(for: telemetryReceiver.trackName) {
                            Button("Delete Saved Track") {
                                telemetryReceiver.deleteLearnedTrack(for: telemetryReceiver.trackName)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                    }
                    
                    if isRecording {
                        VStack(spacing: 4) {
                            Text("Recording lap... (\(recordedPoints.count) points)")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("Drive a clean lap to learn the track outline")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                        }
                    } else if !recordedPoints.isEmpty {
                        VStack(spacing: 4) {
                            Text("Recorded \(recordedPoints.count) points")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Preview looks good? Save to use this track outline permanently")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                        }
                    }
                }
            }
            
            // Preview of recorded track
            if !recordedPoints.isEmpty {
                TrackPreviewView(trackPoints: recordedPoints)
                    .frame(height: 200)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .alert("Save Track Outline", isPresented: $showSaveDialog) {
            Button("Save") {
                saveRecordedTrack()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Save this track outline for \(telemetryReceiver.trackName)?")
        }
                .onReceive(telemetryReceiver.$allCarsRecentPositions) { allCarsPositions in
                    if isRecording && !allCarsPositions.isEmpty {
                        // Throttle track generation to prevent performance issues
                        // Only update every 2 seconds to avoid freezing
                        let now = Date()
                        if lastUpdateTime == nil || now.timeIntervalSince(lastUpdateTime!) > 2.0 {
                            lastUpdateTime = now
                            
                            // Generate track outline from all cars' current data
                            DispatchQueue.global(qos: .userInitiated).async {
                                let newOutline = telemetryReceiver.generateTrackOutlineFromAllCars()
                                if !newOutline.isEmpty {
                                    DispatchQueue.main.async {
                                        recordedPoints = newOutline
                                    }
                                }
                            }
                        }
                    }
                }
    }
    
    private func startRecording() {
        if isRecording {
            // Stop recording
            isRecording = false
        } else {
            // Start recording
            recordedPoints.removeAll()
            isRecording = true
        }
    }
    
    private func saveRecordedTrack() {
        telemetryReceiver.saveLearnedTrack(points: recordedPoints, for: telemetryReceiver.trackName)
        recordedPoints.removeAll()
    }
}

struct TrackPreviewView: View {
    let trackPoints: [CGPoint]
    
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard trackPoints.count > 1 else { return }
                
                let rect = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16)
                var path = Path()
                
                let firstPoint = trackPoints[0]
                let startPoint = CGPoint(
                    x: rect.minX + rect.width * firstPoint.x,
                    y: rect.minY + rect.height * (1 - firstPoint.y)
                )
                path.move(to: startPoint)
                
                for point in trackPoints.dropFirst() {
                    let screenPoint = CGPoint(
                        x: rect.minX + rect.width * point.x,
                        y: rect.minY + rect.height * (1 - point.y)
                    )
                    path.addLine(to: screenPoint)
                }
                                let style = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                ctx.stroke(path, with: .color(Color.blue.opacity(0.7)), style: style)
            }
        }
    }
}
