import WidgetKit
import SwiftUI

/// The widget extension's entry point. A `WidgetBundle` leaves room to add more
/// widgets later (e.g. a practice-progress widget) without restructuring.
@main
struct WordWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordWidget()
    }
}
