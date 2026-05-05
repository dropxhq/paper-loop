import Foundation
import CoreGraphics

enum AnchorData: Codable {
    case html(elementId: String, htmlURL: URL, charOffset: Int? = nil)
    case pdf(page: Int, bbox: CGRect)
}
