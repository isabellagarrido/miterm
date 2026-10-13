import SwiftUI

struct WorkspaceOverviewView: View {
    @ObservedObject private var sessionStore = WorkspaceSessionStore.shared

    private let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 14),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workspace Overview")
                    .font(.system(size: 22, weight: .semibold))
                Text("Open terminal tabs from Ghostty’s window groups.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if sessionStore.sessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "terminal")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No Open Sessions")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Open a terminal tab to see it here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(sessionStore.sessions) { session in
                            WorkspaceSessionCard(session: session) {
                                sessionStore.selectSession(session.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(22)
        .frame(width: 760, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { sessionStore.refresh() }
    }
}

private struct WorkspaceSessionCard: View {
    let session: WorkspaceSessionSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    Image(systemName: "terminal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(session.isSelected ? "Selected" : "Inactive", systemImage: session.isSelected ? "circle.inset.filled" : "circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(session.isSelected ? Color.accentColor : Color.secondary)
                }

                Text(session.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

                HStack(spacing: 6) {
                    Image(systemName: session.hasActiveBell ? "bell.badge" : "minus.circle")
                    Text(session.activityDescription)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        session.isSelected ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor),
                        lineWidth: session.isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.title), \(session.isSelected ? "selected" : "inactive"), \(session.activityDescription)")
    }
}
