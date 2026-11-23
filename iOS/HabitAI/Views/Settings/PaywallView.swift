import SwiftUI
import StoreKit

@MainActor
class StoreViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var purchaseSuccess = false

    let productIds = [
        "com.yourname.habitai.premium.monthly",
        "com.yourname.habitai.premium.yearly",
        "com.yourname.habitai.premium.lifetime"
    ]

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }
        isLoading = false
    }

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    try await APIClient.shared.verifySubscription(
                        transactionId: transaction.id.description,
                        productId: product.id
                    )
                    purchaseSuccess = true
                case .unverified:
                    purchaseError = "Purchase verification failed"
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval"
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            var transactions: [[String: String]] = []
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    transactions.append(["productId": transaction.productID, "transactionId": transaction.id.description])
                }
            }
            if !transactions.isEmpty {
                purchaseSuccess = true
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isLoading = false
    }
}

struct PaywallView: View {
    @StateObject private var store = StoreViewModel()
    @State private var selectedProduct: Product?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#F59E0B"))
                    Text("Unlock Premium")
                        .font(.largeTitle).bold()
                    Text("AI coaching that actually helps you grow")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "infinity", text: "Unlimited habits (free: 3 max)")
                    FeatureRow(icon: "brain.head.profile", text: "Weekly AI coaching summaries")
                    FeatureRow(icon: "bubble.left.and.bubble.right.fill", text: "Chat with your AI coach anytime")
                    FeatureRow(icon: "mic.fill", text: "Voice check-ins — just talk")
                    FeatureRow(icon: "chart.bar.fill", text: "Advanced analytics & insights")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)

                // Product selection
                if store.isLoading {
                    ProgressView()
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.products) { product in
                            ProductRow(product: product, isSelected: selectedProduct?.id == product.id) {
                                selectedProduct = product
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Purchase button
                if let product = selectedProduct ?? store.products.first {
                    VStack(spacing: 12) {
                        Button {
                            Task { await store.purchase(product) }
                        } label: {
                            Text("Start 7-Day Free Trial")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#6366F1"))
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)

                        Button("Restore Purchases") {
                            Task { await store.restorePurchases() }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                if let error = store.purchaseError {
                    Text(error).foregroundColor(.red).font(.caption).padding(.horizontal)
                }

                Text("Cancel anytime. Billed through the App Store.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
        }
        .task { await store.loadProducts() }
        .onChange(of: store.purchaseSuccess) { success in
            if success { dismiss() }
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#6366F1"))
                .frame(width: 24)
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}

struct ProductRow: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    var badge: String? {
        if product.id.contains("yearly") { return "BEST VALUE" }
        return nil
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2).bold()
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(hex: "#F59E0B"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    Text(product.description).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundColor(Color(hex: "#6366F1"))
            }
            .padding()
            .background(isSelected ? Color(hex: "#6366F1").opacity(0.1) : Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "#6366F1") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
