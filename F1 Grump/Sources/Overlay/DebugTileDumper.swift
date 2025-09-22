// README: DebugTileDumper
// Helper to render a single tile for inspection and write it to the app's Documents.

import Foundation

public enum DebugTileDumper {
    public static func dumpPNG(_ data: Data, filename: String = "tile.png") {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docs.appendingPathComponent(filename)
        try? data.write(to: url)
        print("Wrote tile to", url.path)
    }
}


