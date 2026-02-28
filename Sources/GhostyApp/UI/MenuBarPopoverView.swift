import SwiftUI

struct MenuBarPopoverView: View {
    let onToggleGhost: () -> Void
    let onRetreatGhost: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ghost in the Machine")
                .font(.headline)

            Text("Use ⌘⇧G to wake and listen")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Wake / Listen") {
                    onToggleGhost()
                }
                Button("Sleep") {
                    onRetreatGhost()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
