import SwiftUI

/// Shown when the on-disk database cannot be opened — avoids silently starting with empty in-memory data.
struct DataStoreRecoveryView: View {
    let failure: PersistenceFailure
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()

            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.cycleSage)
                .accessibilityHidden(true)

            Text("couldn’t open your data")
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(Color.cycleText)

            Text(failure.userMessage)
                .font(.body)
                .foregroundStyle(Color.cycleSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .openFailed(_, let backupAvailable) = failure, backupAvailable {
                Text("MyLune saved an automatic backup before this launch. Contact support if retry doesn’t work — your history may still be on this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
            }

            Button("Try again", action: onRetry)
                .buttonStyle(PrimaryButtonStyle())

            Link(destination: URL(string: "mailto:\(LuneLegal.supportEmail)?subject=MyLune%20data%20recovery")!) {
                Label("Contact support", systemImage: "envelope")
            }
            .font(.subheadline.weight(.semibold))

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cycleBackground.ignoresSafeArea())
    }
}

#Preview {
    DataStoreRecoveryView(
        failure: .openFailed(message: "Sample error", backupAvailable: true),
        onRetry: {}
    )
}
