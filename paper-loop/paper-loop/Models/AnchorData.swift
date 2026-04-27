import Foundation
import CoreGraphics

enum AnchorData: Codable {
    case html(elementId: String, htmlURL: URL)
    case pdf(page: Int, bbox: CGRect)
}
