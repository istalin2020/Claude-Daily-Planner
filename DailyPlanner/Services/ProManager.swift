import StoreKit
import SwiftUI

// MARK: - Subscription Info
struct SubscriptionInfo {
    let planName: String
    let price: String
    let purchaseDate: Date
    let expirationDate: Date?
    let productID: String
}

// MARK: - Pro Manager
@MainActor
class ProManager: ObservableObject {
    static let shared = ProManager()

    @Published var isPro: Bool
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String? = nil
    @Published var productsLoaded = false
    @Published var activeSubscription: SubscriptionInfo? = nil

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
        purchaseError = nil
        do {
            let loaded = try await Product.products(for: [monthlyID, yearlyID])
            products = loaded.sorted { $0.price < $1.price }
            productsLoaded = !loaded.isEmpty
            if loaded.isEmpty {
                purchaseError = "Subscriptions are being set up. Please try again in a few minutes."
            }
        } catch {
            purchaseError = "Could not connect to the App Store: \(error.localizedDescription)"
            productsLoaded = false
        }
        isLoading = false
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async -> SubscriptionInfo? {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try ProManager.checkVerified(verification)
                await transaction.finish()
                setPro(true)

                let planName = transaction.productID == yearlyID ? "Pro Yearly" : "Pro Monthly"
                let info = SubscriptionInfo(
                    planName: planName,
                    price: product.displayPrice,
                    purchaseDate: transaction.purchaseDate,
                    expirationDate: transaction.expirationDate,
                    productID: transaction.productID
                )
                activeSubscription = info
                return info

            case .userCancelled:
                return nil
            case .pending:
                purchaseError = "Purchase is pending approval (e.g. Ask to Buy)."
                return nil
            @unknown default:
                return nil
            }
        } catch {
            purchaseError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await verifyProStatus()
            if !isPro {
                purchaseError = "No active subscription found for this Apple ID."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Verify Active Entitlement
    func verifyProStatus() async {
        for id in [monthlyID, yearlyID] {
            if let result = await Transaction.currentEntitlement(for: id) {
                if case .verified(let transaction) = result {
                    setPro(true)

                    let product = products.first { $0.id == id }
                    let planName = id == yearlyID ? "Pro Yearly" : "Pro Monthly"
                    activeSubscription = SubscriptionInfo(
                        planName: planName,
                        price: product?.displayPrice ?? "",
                        purchaseDate: transaction.purchaseDate,
                        expirationDate: transaction.expirationDate,
                        productID: transaction.productID
                    )
                    return
                }
            }
        }
        setPro(false)
        activeSubscription = nil
    }

    // MARK: - Transaction Listener
    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try ProManager.checkVerified(result)
                    if transaction.productID == self.monthlyID ||
                       transaction.productID == self.yearlyID {
                        await transaction.finish()
                        await MainActor.run {
                            self.setPro(true)
                            let planName = transaction.productID == self.yearlyID ? "Pro Yearly" : "Pro Monthly"
                            self.activeSubscription = SubscriptionInfo(
                                planName: planName,
                                price: "",
                                purchaseDate: transaction.purchaseDate,
                                expirationDate: transaction.expirationDate,
                                productID: transaction.productID
                            )
                        }
                    }
                } catch { /* ignore unverified */ }
            }
        }
    }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw ProError.verificationFailed
        case .verified(let value): return value
        }
    }

    func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: proKey)
    }

    // MARK: - Finish All Unfinished Transactions
    func finishAllUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
    }

    // MARK: - Convenience
    var monthlyProduct: Product? { products.first { $0.id == monthlyID } }
    var yearlyProduct:  Product? { products.first { $0.id == yearlyID } }

    var monthlyPriceString: String { monthlyProduct?.displayPrice ?? "₹99" }
    var yearlyPriceString:  String { yearlyProduct?.displayPrice  ?? "₹999" }

    var yearlySavings: String {
        if let m = monthlyProduct, let y = yearlyProduct {
            let diff = (m.price * 12) - y.price
            return diff > 0 ? y.priceFormatStyle.format(diff) : ""
        }
        return "₹189"
    }

    static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: date)
    }
}

enum ProError: Error { case verificationFailed }

// MARK: - Pro Feature Gate View
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
            ScrollView {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.65, blue: 0.0).opacity(0.85),
                                 Color(red: 1.0, green: 0.40, blue: 0.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(height: 80)
                    .overlay(
                        HStack(spacing: 14) {
                            Image(systemName: featureIcon)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(featureName)
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("PRO Feature")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    )

                    VStack(spacing: 24) {
                        Spacer(minLength: 40)

                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.78, blue: 0.0),
                                             Color(red: 1.0, green: 0.45, blue: 0.0)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 8) {
                            Text("\(featureName) is PRO")
                                .font(.title3).fontWeight(.bold)
                            Text("Upgrade to unlock all 15 premium features including\nHabit Tracker, Sleep Tracker, Medication Reminders,\nPomodoro Timer, Spending Trends and more.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)

                        Button(action: { showUpgrade = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 14))
                                Text("Upgrade to PRO")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color(red: 1.0, green: 0.65, blue: 0.0),
                                                        Color(red: 1.0, green: 0.40, blue: 0.0)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 32)

                        Spacer(minLength: 40)
                    }
                }
            }
            .sheet(isPresented: $showUpgrade) {
                ProUpgradeView().environmentObject(pro)
            }
        }
    }
}

// MARK: - Inline Pro Badge
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
