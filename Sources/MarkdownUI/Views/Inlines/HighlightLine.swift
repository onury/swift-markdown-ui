import SwiftUI

/// The bounds of the marker that carries a highlight anchor's id, one per marker.
struct HighlightAnchorMarkerKey: PreferenceKey {
  static let defaultValue: [Anchor<CGRect>] = []

  static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
    value += nextValue()
  }
}
