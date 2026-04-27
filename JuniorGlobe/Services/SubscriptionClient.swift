//
//  SubscriptionClient.swift
//  JuniorGlobe
//

import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

struct SubscriptionCustomerState: Equatable, Sendable {
    let hasPremiumEntitlement: Bool
}

struct SubscriptionPackage: Identifiable, Hashable, Sendable {
    let id: String
    let productIdentifier: String
    let title: String
    let subtitle: String
    let priceLabel: String
}

struct SubscriptionOffering: Equatable, Sendable {
    let packages: [SubscriptionPackage]
}

enum SubscriptionStoreError: LocalizedError {
    case sdkNotInstalled
    case notConfigured
    case noOfferingAvailable
    case packageUnavailable
    case noRestorablePurchase

    var errorDescription: String? {
        switch self {
        case .sdkNotInstalled:
            return "RevenueCat SDK 尚未安裝到專案。"
        case .notConfigured:
            return "RevenueCat 尚未設定完成，請先確認 API key。"
        case .noOfferingAvailable:
            return "目前還沒有可用的訂閱方案。"
        case .packageUnavailable:
            return "選到的訂閱方案已失效，請重新整理。"
        case .noRestorablePurchase:
            return "這個 Apple 帳號目前沒有可還原的訂閱。"
        }
    }
}

protocol SubscriptionClient: Sendable {
    func fetchCustomerState() async throws -> SubscriptionCustomerState
    func fetchCurrentOffering() async throws -> SubscriptionOffering?
    func purchase(packageID: String) async throws -> SubscriptionCustomerState
    func restorePurchases() async throws -> SubscriptionCustomerState
}

enum RevenueCatBootstrap {
    private static var didConfigure = false

    static func configureIfNeeded() {
#if canImport(RevenueCat)
        guard didConfigure == false else {
            return
        }

        let apiKey = AppConfig.revenueCatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard apiKey.isEmpty == false else {
            return
        }

        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        didConfigure = true
#endif
    }

    static var isConfigured: Bool {
        didConfigure
    }
}

struct LiveSubscriptionClient: SubscriptionClient {
    func fetchCustomerState() async throws -> SubscriptionCustomerState {
#if canImport(RevenueCat)
        try configureIfNeeded()
        let customerInfo = try await Purchases.shared.customerInfo()
        return Self.customerState(from: customerInfo)
#else
        throw SubscriptionStoreError.sdkNotInstalled
#endif
    }

    func fetchCurrentOffering() async throws -> SubscriptionOffering? {
#if canImport(RevenueCat)
        try configureIfNeeded()
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else {
            return nil
        }

        return SubscriptionOffering(
            packages: current.availablePackages.map(Self.package(from:))
        )
#else
        throw SubscriptionStoreError.sdkNotInstalled
#endif
    }

    func purchase(packageID: String) async throws -> SubscriptionCustomerState {
#if canImport(RevenueCat)
        try configureIfNeeded()
        let offerings = try await Purchases.shared.offerings()
        guard
            let current = offerings.current,
            let package = Self.matchingPackage(for: packageID, in: current)
        else {
            throw SubscriptionStoreError.packageUnavailable
        }

        let result = try await Purchases.shared.purchase(package: package)
        return Self.customerState(from: result.customerInfo)
#else
        throw SubscriptionStoreError.sdkNotInstalled
#endif
    }

    func restorePurchases() async throws -> SubscriptionCustomerState {
#if canImport(RevenueCat)
        try configureIfNeeded()
        let customerInfo = try await Purchases.shared.restorePurchases()
        let state = Self.customerState(from: customerInfo)
        guard state.hasPremiumEntitlement else {
            throw SubscriptionStoreError.noRestorablePurchase
        }

        return state
#else
        throw SubscriptionStoreError.sdkNotInstalled
#endif
    }

#if canImport(RevenueCat)
    private func configureIfNeeded() throws {
        RevenueCatBootstrap.configureIfNeeded()
        if RevenueCatBootstrap.isConfigured == false {
            throw SubscriptionStoreError.notConfigured
        }
    }

    private static func customerState(from customerInfo: CustomerInfo) -> SubscriptionCustomerState {
        SubscriptionCustomerState(
            hasPremiumEntitlement: customerInfo.entitlements.active[AppConfig.revenueCatEntitlementID] != nil
        )
    }

    private static func package(from package: RevenueCat.Package) -> SubscriptionPackage {
        SubscriptionPackage(
            id: package.storeProduct.productIdentifier,
            productIdentifier: package.storeProduct.productIdentifier,
            title: package.storeProduct.localizedTitle,
            subtitle: package.storeProduct.localizedDescription,
            priceLabel: package.storeProduct.localizedPriceString
        )
    }

    private static func matchingPackage(for packageID: String, in offering: Offering) -> RevenueCat.Package? {
        offering.availablePackages.first { package in
            package.storeProduct.productIdentifier == packageID || package.identifier == packageID
        }
    }
#endif
}
