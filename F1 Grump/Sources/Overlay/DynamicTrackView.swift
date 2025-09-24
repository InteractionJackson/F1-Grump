// README: DynamicTrackView
// Draws a track outline using telemetry data points instead of SVG files.
// Creates a dynamic track outline from the player's position history.

import SwiftUI

public struct DynamicTrackView: View {
    public let trackOutline: [CGPoint]
    public let carPoints01: [CGPoint]
    public let playerIndex: Int
    public let teamIds: [UInt8]
    public let worldAspect: CGFloat // dx/dz aspect ratio from telemetry
    public var inset: CGFloat = 8
    public var rotationDegrees: Double = 0 // Track rotation
    public var flipHorizontally: Bool = false // Horizontal flip
    
    public init(trackOutline: [CGPoint], carPoints01: [CGPoint], playerIndex: Int, teamIds: [UInt8] = [], worldAspect: CGFloat = 1.0, inset: CGFloat = 8, rotationDegrees: Double = 0, flipHorizontally: Bool = false) {
        self.trackOutline = trackOutline
        self.carPoints01 = carPoints01
        self.playerIndex = playerIndex
        self.teamIds = teamIds
        self.worldAspect = worldAspect
        self.inset = inset
        self.rotationDegrees = rotationDegrees
        self.flipHorizontally = flipHorizontally
    }
    
    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
        #if DEBUG
        print("DynamicTrackView: teamIds=\(teamIds.count), carPoints=\(carPoints01.count), trackPoints=\(trackOutline.count)")
        print("DynamicTrackView: worldAspect=\(worldAspect), rotation=\(rotationDegrees), flip=\(flipHorizontally)")
        if !carPoints01.isEmpty {
            let first = carPoints01[0]
            print("DynamicTrackView: First car point: (\(first.x), \(first.y))")
        }
        if !trackOutline.isEmpty {
            let first = trackOutline[0]
            print("DynamicTrackView: First track point: (\(first.x), \(first.y))")
        }
        #endif
                
                // Calculate the actual bounds of the track outline to preserve aspect ratio
                let availableRect = CGRect(x: inset, y: inset, width: size.width - inset*2, height: size.height - inset*2)
                let rect = aspectRatioFitRect(for: trackOutline, in: availableRect)
                
                // Draw track outline if we have enough points
                if trackOutline.count > 3 {
                    var path = Path()
                    let transformedPoints = trackOutline.map { transformPoint($0) }
                    
                    let firstPoint = transformedPoints[0]
                    let startPoint = CGPoint(
                        x: rect.minX + rect.width * firstPoint.x,
                        y: rect.minY + rect.height * (1 - firstPoint.y)
                    )
                    path.move(to: startPoint)
                    
                    for point in transformedPoints.dropFirst() {
                        let screenPoint = CGPoint(
                            x: rect.minX + rect.width * point.x,
                            y: rect.minY + rect.height * (1 - point.y)
                        )
                        path.addLine(to: screenPoint)
                    }
                    
                    // Draw track outline as wider stroke for better visibility
                    let style = StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                    ctx.stroke(path, with: .color(Color.white.opacity(0.4)), style: style)
                }
                
                // Draw car dots with team colors
                for (i, p) in carPoints01.enumerated() {
                    let transformedPoint = transformPoint(p)
                    let x = rect.minX + rect.width * transformedPoint.x
                    let y = rect.minY + rect.height * (1 - transformedPoint.y)
                    let r: CGFloat = (i == playerIndex) ? 7 : 5 // Slightly larger for better visibility
                    
                    // Get team color
                    let teamId = i < teamIds.count ? teamIds[i] : 0
                    let baseColor = TeamColors.colorForTeam(teamId)
                    let color: Color = (i == playerIndex) ? 
                        TeamColors.brightColorForTeam(teamId) : baseColor.opacity(0.9)
                    
                    #if DEBUG
                    if i < 3 { // Debug first 3 cars
                        print("DynamicTrackView: Car \(i) - TeamID: \(teamId), Team: \(TeamColors.nameForTeam(teamId)), IsPlayer: \(i == playerIndex)")
                    }
                    #endif
                    
                    let ellipse = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2))
                    ctx.fill(ellipse, with: .color(color))
                    
                    // Add stroke to all car dots
                    ctx.stroke(ellipse, with: .color(Color(hex: "#31233B")), lineWidth: 1)
                    
                    // Add additional white outline for player car
                    if i == playerIndex {
                        ctx.stroke(ellipse, with: .color(Color.white.opacity(0.8)), lineWidth: 1.5)
                    }
                }
            }
        }
    }
    
    // Calculate a rectangle that preserves the track's aspect ratio
    private func aspectRatioFitRect(for points: [CGPoint], in availableRect: CGRect) -> CGRect {
        guard !points.isEmpty else { return availableRect }
        
        // Use the world aspect ratio from telemetry data for accurate proportions
        // This represents the actual dx/dz ratio from the F1 world coordinates
        // For 90° rotations, we need to invert the aspect ratio
        let trackAspectRatio = (rotationDegrees == 90 || rotationDegrees == -90 || rotationDegrees == 270) ? 
            1.0 / worldAspect : worldAspect
        let availableAspectRatio = availableRect.width / availableRect.height
        
        #if DEBUG
        print("DynamicTrackView: Track aspect ratio=\(trackAspectRatio), Available aspect ratio=\(availableAspectRatio)")
        #endif
        
        let fittedRect: CGRect
        
        if trackAspectRatio > availableAspectRatio {
            // Track is wider than available space - fit to width
            let fittedHeight = availableRect.width / trackAspectRatio
            fittedRect = CGRect(
                x: availableRect.minX,
                y: availableRect.midY - fittedHeight / 2,
                width: availableRect.width,
                height: fittedHeight
            )
        } else {
            // Track is taller than available space - fit to height
            let fittedWidth = availableRect.height * trackAspectRatio
            fittedRect = CGRect(
                x: availableRect.midX - fittedWidth / 2,
                y: availableRect.minY,
                width: fittedWidth,
                height: availableRect.height
            )
        }
        
        return fittedRect
    }
    
    // Transform a point with rotation and horizontal flip
    private func transformPoint(_ point: CGPoint) -> CGPoint {
        var transformed = point
        
        // Apply rotation around center (0.5, 0.5)
        if rotationDegrees != 0 {
            let radians = rotationDegrees * .pi / 180
            let centerX: CGFloat = 0.5
            let centerY: CGFloat = 0.5
            
            let dx = transformed.x - centerX
            let dy = transformed.y - centerY
            
            let cosAngle = cos(radians)
            let sinAngle = sin(radians)
            
            transformed.x = dx * cosAngle - dy * sinAngle + centerX
            transformed.y = dx * sinAngle + dy * cosAngle + centerY
        }
        
        // Apply horizontal flip
        if flipHorizontally {
            transformed.x = 1.0 - transformed.x
        }
        
        return transformed
    }
}
