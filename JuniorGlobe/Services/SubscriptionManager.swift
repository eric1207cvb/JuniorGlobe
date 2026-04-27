//
//  SubscriptionManager.swift
//  JuniorGlobe
//

import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var availablePackages: [SubscriptionPackage] = []
    @Published private(set) var isLoadingOfferings = false
    @Published private(set) var isRefreshingStatus = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var storeErrorMessage: String?

    private var customerState = SubscriptionCustomerState(hasPremiumEntitlement: false)
    private let client: SubscriptionClient

    init(client: SubscriptionClient? = nil) {
        self.client = client ?? LiveSubscriptionClient()
    }

    var isSubscriber: Bool {
        customerState.hasPremiumEntitlement
    }

    func refreshAll() async {
        await refreshSubscriptionStatus()
        await loadOfferings()
    }

    func refreshSubscriptionStatus() async {
        isRefreshingStatus = true
        defer { isRefreshingStatus = false }

        do {
            customerState = try await client.fetchCustomerState()
            storeErrorMessage = nil
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }

        do {
            let offering = try await client.fetchCurrentOffering()
            availablePackages = offering?.packages ?? []
            if availablePackages.isEmpty {
                storeErrorMessage = SubscriptionStoreError.noOfferingAvailable.localizedDescription
            } else {
                storeErrorMessage = nil
            }
        } catch {
            availablePackages = []
            storeErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func purchase(_ package: SubscriptionPackage) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            customerState = try await client.purchase(packageID: package.id)
            storeErrorMessage = nil
            return isSubscriber
        } catch {
            storeErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        isRestoring = true
        defer { isRestoring = false }

        do {
            customerState = try await client.restorePurchases()
            storeErrorMessage = nil
            return isSubscriber
        } catch {
            storeErrorMessage = error.localizedDescription
            return false
        }
    }

    func clearStoreError() {
        storeErrorMessage = nil
    }
}
