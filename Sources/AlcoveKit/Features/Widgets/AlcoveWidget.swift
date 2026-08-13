import SwiftUI

@MainActor
public protocol AlcoveWidget: Identifiable, Sendable {
    var id: String { get }
    var displayName: String { get }
    var systemImage: String { get }
    var isEnabled: Bool { get }
    
    func renderView() -> AnyView
}

public extension AlcoveWidget {
    @MainActor
    func eraseToAnyWidget() -> AnyAlcoveWidget {
        AnyAlcoveWidget(self)
    }
}

public struct AnyAlcoveWidget: Identifiable, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let systemImage: String
    public let isEnabled: Bool
    private let _renderView: @MainActor () -> AnyView
    
    @MainActor
    public init<W: AlcoveWidget>(_ widget: W) {
        self.id = widget.id
        self.displayName = widget.displayName
        self.systemImage = widget.systemImage
        self.isEnabled = widget.isEnabled
        self._renderView = { widget.renderView() }
    }
    
    @MainActor
    public func renderView() -> AnyView {
        _renderView()
    }
}
