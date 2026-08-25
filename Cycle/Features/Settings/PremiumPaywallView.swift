import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("lune premium")
                        .font(.system(.largeTitle, design: .serif).weight(.medium))
                        .foregroundStyle(Color.cycleText)

                    Text("go deeper with on-device AI and pattern insights — still private, still on your phone.")
                        .font(.body)
                        .foregroundStyle(Color.cycleSecondary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(LunePremium.benefits, id: \.self) { benefit in
                            Label {
                                Text(benefit)
                                    .foregroundStyle(Color.cycleText)
                            } icon: {
                                LuneSymbolIcon(
                                    name: LuneSymbolName.sparkles,
                                    style: .accent,
                                    font: .body
                                )
                            }
                            .font(.subheadline.weight(.medium))
                            .labelStyle(.titleAndIcon)
                        }
                    }
                    .padding(.vertical, 4)

                    if let product = env.premium.monthlyProduct {
                        Text(product.displayPrice + " / month")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.cycleText)
                    }

                    Button {
                        Task { await purchase() }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                            } else {
                                Text("Start Lune Premium")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isPurchasing || env.premium.monthlyProduct == nil)

                    Button("Restore purchases") {
                        Task { await restore() }
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))

                    Text("Payment is charged to your Apple ID. Cancel anytime in Settings → Subscriptions. Cycle data stays on this device.")
                        .font(.caption)
                        .foregroundStyle(Color.cycleSecondary)
                }
                .padding(24)
            }
            .background(Color.cycleBackground.ignoresSafeArea())
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Premium", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: env.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
        }
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await env.premium.purchaseMonthly()
            await env.syncPremiumEntitlement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        await env.premium.restorePurchases()
        await env.syncPremiumEntitlement()
        if !env.isPremium {
            errorMessage = "No active Premium subscription found for this Apple ID."
        }
    }
}

#Preview {
    PremiumPaywallView()
        .environment(AppEnvironment.preview())
}
