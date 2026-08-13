import SwiftUI
import AppKit

public struct DropShelfTargetView: View {
    @State private var isHovering: Bool = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AlcoveTheme.accentPurple.opacity(0.35), AlcoveTheme.accentBlue.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                
                Image(systemName: "arrow.down.doc.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Drop Shelf & Quick Stash")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AlcoveTheme.textPrimary)
                
                Text("Drag any files, URLs, or text snippets to stash")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AlcoveTheme.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AlcoveTheme.accentTeal)
                Text("Drop Zone")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AlcoveTheme.accentTeal)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AlcoveTheme.accentTeal.opacity(0.14))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                .fill(isHovering ? AlcoveTheme.cardHoverBackground : AlcoveTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(
                            isHovering ? AnyShapeStyle(AlcoveTheme.accentBlue.opacity(0.8)) : AnyShapeStyle(AlcoveTheme.cardBorder),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                )
        )
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovering = h } }
    }
}

public final class DropHandler: @unchecked Sendable {
    public static func handleIncoming(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let fileURL = url else { return }
                    Task { @MainActor in
                        ClipboardShelfWidget.shared.recordFile(fileURL)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.text") {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let content = text else { return }
                    Task { @MainActor in
                        ClipboardShelfWidget.shared.recordText(content)
                    }
                }
            }
        }
        return true
    }
}
