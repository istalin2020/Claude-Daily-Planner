import StoreKit
import SwiftUI

// MARK: - Pro Manager
@MainActor
class ProManager: ObservableObject {
    static let shared = ProManager()

    @Published var isPro: Bool
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String? = nil

    private let monthlyID = "com.istalin.dailyplanner.pro.monthly"
    private let yearlyID  = "com.istalin.dailyplanner.pro.yearly"
    private let proKey    = "dailyplanner_is_pro"

    private var transactionListener: Task<Void, Error>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: proKey)
        transactionListener = startTransactionListener()
        Task {
            await loadProducts()
            await verifyProStatus()
        }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        do {
            let loaded = try await Product.products(for: [monthlyID, yearlyID])
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            // StoreKit unavailable (simulator / no App Store Connect config) — use display fallback
        }
        isLoading = false
    }

    // MARK: - Purchase
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setPro(true)
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await verifyProStatus()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Verify Active Entitlement
    func verifyProStatus() async {
        for id in [monthlyID, yearlyID] {
            if let result = await Transaction.currentEntitlement(for: id) {
                if case .verified = result {
                    setPro(true)
                    return
                }
            }
        }
        // If we can confirm no active entitlement through StoreKit AND
        // products were loaded successfully, clear the pro flag.
        if !products.isEmpty {
            setPro(false)
        }
    }

    // MARK: - Transaction Listener
    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    if transaction.productID == self.monthlyID ||
                       transaction.productID == self.yearlyID {
                        await transaction.finish()
                        await MainActor.run { self.setPro(true) }
                    }
                } catch { /* ignore unverified */ }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw ProError.verificationFailed
        case .verified(let value): return value
        }
    }

    func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: proKey)
    }

    // MARK: - Convenience
    var monthlyProduct: Product? { products.first { $0.id == monthlyID } }
    var yearlyProduct:  Product? { products.first { $0.id == yearlyID } }

    var monthlyPriceString: String { monthlyProduct?.displayPrice ?? "₹99" }
    var yearlyPriceString:  String { yearlyProduct?.displayPrice  ?? "₹999" }

    /// How much the user saves per year by choosing yearly vs monthly
    var yearlySavings: String {
        if let m = monthlyProduct, let y = yearlyProduct {
            let diff = (m.price * 12) - y.price
            return diff > 0 ? y.priceFormatStyle.format(diff) : ""
        }
        return "₹189"
    }
}

enum ProError: Error { case verificationFailed }

// MARK: - Pro Feature Gate View
/// Wraps any content: shows it normally when PRO, else shows a locked overlay.
struct ProGate<Content: View>: View {
    @EnvironmentObject private var pro: ProManager
    let featureName: String
    let featureIcon: String
    @ViewBuilder let content: () -> Content
    @State private var showUpgrade = false

    var body: some View {
        if pro.isPro {
            content()
        } else {
            ZStack {
                content()
                    .blur(radius: 6)
                    .allowsHitTesting(false)

                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.0))

                    VStack(spacing: 6) {
                        Text("\(featureName) is PRO")
                            .font(.headline).fontWeight(.bold)
                        Text("Upgrade to unlock all 15 premium features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { showUpgrade = true }) {
                        Text("Upgrade to PRO")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color(red: 1.0, green: 0.65, blue: 0.0),
                                                        Color(red: 1.0, green: 0.40, blue: 0.0)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(24)
                    }
                }
                .padding(28)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(24)
            }
            .sheet(isPresented: $showUpgrade) {
                ProUpgradeView().environmentObject(pro)
            }
        }
    }
}

// MARK: - Inline Pro Badge (for locked controls within a form/sheet)
struct ProInlineBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 8))
            Text("PRO")
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(
            LinearGradient(colors: [Color(red: 1.0, green: 0.78, blue: 0.0),
                                    Color(red: 1.0, green: 0.55, blue: 0.0)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
