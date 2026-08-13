import SwiftUI
import AppKit

@MainActor
@Observable
public final class AntigravityAgentWidget: AlcoveWidget, @unchecked Sendable {
    public static let shared = AntigravityAgentWidget()
    
    public let id: String = "alcove.widget.antigravity"
    public let displayName: String = "Antigravity Agent"
    public let systemImage: String = "sparkles"
    public var isEnabled: Bool = true
    
    public var quickPrompt: String = ""
    public var statusText: String = "Ready"
    public var isExecuting: Bool = false
    public var recentLogs: [String] = [
        "Agent idle • Ready for tasks or /goal commands"
    ]
    
    public func executeAgentAction(customPrompt: String? = nil) {
        let query = (customPrompt ?? quickPrompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        self.quickPrompt = ""
        self.statusText = "Running..."
        self.isExecuting = true
        self.recentLogs.insert("▶️ Executing: \"\(query)\"", at: 0)
        
        Task {
            do {
                let response = try await AntigravityWorkflowEngine.shared.dispatchWorkflow(prompt: query)
                await MainActor.run {
                    self.statusText = "ID: " + response.executionId
                    self.isExecuting = false
                    self.recentLogs.insert("✅ [\(response.executionId)] \(response.message)", at: 0)
                }
            } catch {
                await MainActor.run {
                    self.statusText = "Failed"
                    self.isExecuting = false
                    self.recentLogs.insert("❌ Error: \(error.localizedDescription)", at: 0)
                }
            }
        }
    }
    
    public func renderView() -> AnyView {
        AnyView(AntigravityAgentView(model: self))
    }
}

public struct AntigravityAgentView: View {
    @Bindable var model: AntigravityAgentWidget
    @State private var isHovering: Bool = false
    @FocusState private var isFocused: Bool
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AlcoveTheme.neonAIGlow)
                    
                    Text("Antigravity AI")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(AlcoveTheme.textPrimary)
                }
                
                Spacer()
                
                HStack(spacing: 3) {
                    Circle()
                        .fill(model.isExecuting ? AlcoveTheme.accentOrange : AlcoveTheme.accentGreen)
                        .frame(width: 5, height: 5)
                    
                    Text(model.statusText)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AlcoveTheme.textSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                    .foregroundStyle(AlcoveTheme.textTertiary)
                
                TextField("Prompt AI or run /goal...", text: $model.quickPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(AlcoveTheme.textPrimary)
                    .focused($isFocused)
                    .onSubmit { model.executeAgentAction() }
                
                Button {
                    model.executeAgentAction()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                        Text("↵")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(model.quickPrompt.isEmpty ? AlcoveTheme.textQuaternary : Color.white)
                    .frame(width: 24, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(model.quickPrompt.isEmpty ? Color.white.opacity(0.06) : AlcoveTheme.accentBlue)
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isExecuting)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isFocused ? AnyShapeStyle(AlcoveTheme.accentBlue.opacity(0.7)) : AnyShapeStyle(Color.white.opacity(0.08)),
                                lineWidth: isFocused ? 1.0 : 0.5
                            )
                    )
            )
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

public struct AntigravityAgentFullView: View {
    @State private var model = AntigravityAgentWidget.shared
    @FocusState private var isFieldFocused: Bool
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AlcoveTheme.neonAIGlow)
                    Text("Antigravity AI Workflow Engine")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AlcoveTheme.textPrimary)
                }
                Spacer()
                Text(model.statusText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(model.isExecuting ? AlcoveTheme.accentOrange : AlcoveTheme.accentGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            
            // Spotlight Input Bar
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(AlcoveTheme.accentPurple)
                
                TextField("Ask Antigravity, trigger multi-agent workflows, or execute /goal...", text: $model.quickPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(AlcoveTheme.textPrimary)
                    .focused($isFieldFocused)
                    .onSubmit { model.executeAgentAction() }
                
                Button {
                    model.executeAgentAction()
                } label: {
                    HStack(spacing: 3) {
                        Text("Dispatch")
                            .font(.system(size: 10.5, weight: .semibold))
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AlcoveTheme.accentPurple, AlcoveTheme.accentBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isExecuting)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.40))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AlcoveTheme.neonAIGlow, lineWidth: 1.0)
                    )
            )
            
            // Quick Action Chips
            HStack(spacing: 6) {
                QuickPromptChip(label: "✨ Summarize Workspace", prompt: "Summarize current workspace and active git changes")
                QuickPromptChip(label: "⚡️ /goal Full Task", prompt: "/goal Run deep test verification across all modules")
                QuickPromptChip(label: "🛠 Run Script", prompt: "swift run YasIslandTests")
            }
            
            // Recent Execution Stream Log
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Workflow Dispatch Stream")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(AlcoveTheme.textTertiary)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.recentLogs.prefix(4), id: \.self) { log in
                            Text(log)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(AlcoveTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxHeight: 60)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                .fill(AlcoveTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AlcoveTheme.cardBorder, lineWidth: 0.75)
                )
        )
    }
}

public struct QuickPromptChip: View {
    let label: String
    let prompt: String
    
    public var body: some View {
        Button {
            AntigravityAgentWidget.shared.executeAgentAction(customPrompt: prompt)
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AlcoveTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
    }
}
