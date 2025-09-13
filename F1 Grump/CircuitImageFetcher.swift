import Foundation
import SwiftUI

final class CircuitImageFetcher: ObservableObject {
    @Published var image: UIImage?

    func fetch(from pageURL: URL) {
        URLSession.shared.dataTask(with: pageURL) { [weak self] data, _, _ in
            guard let data, let html = String(data: data, encoding: .utf8) else { return }
            // Find a PNG with "Circuit" in its name
            if let url = self?.firstCircuitPNG(in: html, base: pageURL) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data, let img = UIImage(data: data) else { return }
                    DispatchQueue.main.async { self?.image = img }
                }.resume()
            }
        }.resume()
    }

    private func firstCircuitPNG(in html: String, base: URL) -> URL? {
        // Very loose regex to match circuit assets
        let pattern = #"https?://[^\s"']+?Circuit[^\s"']*?\.png"#
        if let rx = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let ns = html as NSString
            if let m = rx.firstMatch(in: html, options: [], range: NSRange(location: 0, length: ns.length)) {
                let s = ns.substring(with: m.range)
                return URL(string: s)
            }
        }
        // Fallback: relative path like "Italy_Circuit.png"
        if let range = html.range(of: #"[A-Za-z_]+_Circuit\.png"#, options: .regularExpression) {
            let file = String(html[range])
            return URL(string: file, relativeTo: base)
        }
        return nil
    }
}


