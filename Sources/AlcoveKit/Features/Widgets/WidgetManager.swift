import SwiftUI

@MainActor
@Observable
public final class WidgetManager {
    public static let shared = WidgetManager()
    
    public private(set) var activeWidgets: [AnyAlcoveWidget] = []
    
    private init() {
        registerDefaultWidgets()
    }
    
    public func registerDefaultWidgets() {
        self.activeWidgets = [
            MediaControlsWidget.shared.eraseToAnyWidget(),
            ClipboardShelfWidget.shared.eraseToAnyWidget(),
            SystemStatusWidget.shared.eraseToAnyWidget(),
            AntigravityAgentWidget.shared.eraseToAnyWidget()
        ]
    }
    
    public func register(widget: some AlcoveWidget) {
        self.activeWidgets.append(widget.eraseToAnyWidget())
    }
}

public struct WidgetHostGridView: View {
    @State private var widgetManager = WidgetManager.shared
    
    public var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(widgetManager.activeWidgets) { widget in
                widget.renderView()
            }
        }
    }
}
