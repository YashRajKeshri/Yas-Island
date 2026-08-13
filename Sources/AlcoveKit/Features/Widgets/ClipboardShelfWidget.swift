import SwiftUI
import AppKit

@MainActor
@Observable
public final class ClipboardShelfWidget: AlcoveWidget, @unchecked Sendable {
    public static let shared = ClipboardShelfWidget()
    
    public let id: String = "alcove.widget.clipboard"
    public let displayName: String = "Drop Vault"
    public let systemImage: String = "tray.and.arrow.down.fill"
    public var isEnabled: Bool = true
    
    public var items: [String] = [
        "https://yasisland.ai",
        "Package.swift",
        "export ARCHFLAGS='-arch arm64'"
    ]
    
    public func recordText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.removeAll(where: { $0 == trimmed })
        items.insert(trimmed, at: 0)
        if items.count > 16 { items.removeLast() }
    }
    
    public func recordFile(_ url: URL) {
        let name = url.lastPathComponent
        guard !name.isEmpty else { return }
        items.removeAll(where: { $0 == name })
        items.insert(name, at: 0)
        if items.count > 16 { items.removeLast() }
    }
    
    public func removeItem(_ item: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            items.removeAll(where: { $0 == item })
        }
    }
    
    public func renderView() -> AnyView {
        AnyView(ClipboardShelfView(model: self))
    }
}

public struct ClipboardShelfView: View {
    let model: ClipboardShelfWidget
    @State private var isHovering: Bool = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "tray.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AlcoveTheme.accentBlue)
                    Text("Drop Vault")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(AlcoveTheme.textPrimary)
                    
                    Text("\(model.items.count)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(AlcoveTheme.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                
                Spacer()
                
                if !model.items.isEmpty {
                    Button("Clear") {
                        withAnimation(.easeOut(duration: 0.18)) {
                            model.items.removeAll()
                        }
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemRed).opacity(0.85))
                    .buttonStyle(.plain)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if model.items.isEmpty {
                        Text("No stashed items")
                            .font(.system(size: 10))
                            .foregroundStyle(AlcoveTheme.textTertiary)
                    } else {
                        ForEach(model.items.prefix(5), id: \.self) { item in
                            StashPill(title: item)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                .fill(isHovering ? AlcoveTheme.cardHoverBackground : AlcoveTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AlcoveTheme.cardBorder, lineWidth: 0.75)
                )
        )
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovering = h } }
    }
}

public struct ClipboardShelfFullView: View {
    @State private var model = ClipboardShelfWidget.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Stashed Vault Items (\(model.items.count))")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AlcoveTheme.textPrimary)
                Spacer()
                if !model.items.isEmpty {
                    Button("Clear All") {
                        withAnimation { model.items.removeAll() }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .buttonStyle(.plain)
                }
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(model.items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: iconForItem(item))
                            .font(.system(size: 13))
                            .foregroundStyle(colorForItem(item))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(AlcoveTheme.textPrimary)
                                .lineLimit(1)
                            Text(item.hasPrefix("http") ? "URL Link" : "File / Snippet")
                                .font(.system(size: 9))
                                .foregroundStyle(AlcoveTheme.textTertiary)
                        }
                        
                        Spacer()
                        
                        // Copy Button
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(AlcoveTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to Clipboard")
                        
                        // Delete Button
                        Button {
                            model.removeItem(item)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .help("Remove from Vault")
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                .fill(AlcoveTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AlcoveTheme.cardBorder, lineWidth: 0.75)
                )
        )
    }
    
    private func iconForItem(_ item: String) -> String {
        if item.hasPrefix("http") { return "link" }
        if item.contains(".") { return "doc.fill" }
        return "text.quote"
    }
    
    private func colorForItem(_ item: String) -> Color {
        if item.hasPrefix("http") { return AlcoveTheme.accentBlue }
        if item.contains(".") { return AlcoveTheme.accentOrange }
        return AlcoveTheme.accentGreen
    }
}

public struct StashPill: View {
    let title: String
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: title.hasPrefix("http") ? "link" : "doc.text.fill")
                .font(.system(size: 9))
                .foregroundStyle(title.hasPrefix("http") ? AlcoveTheme.accentBlue : AlcoveTheme.accentOrange)
            
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AlcoveTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
