import Foundation

public final class WMFDonateLocalHistory: Codable {

    public let donationTimestamp: String
    public let donationType: DonationType
    public let donationAmount: Decimal
    public let isNative: Bool
    public let isFirstDonation: Bool

    // MARK: Nested Types

    public enum DonationType: String, Codable {
        case oneTime
        case recurring
    }

    public init(donationTimestamp: String, donationType: DonationType, donationAmount: Decimal, isNative: Bool, isFirstDonation: Bool) {
        self.donationTimestamp = donationTimestamp
        self.donationType = donationType
        self.donationAmount = donationAmount
        self.isNative = isNative
        self.isFirstDonation = isFirstDonation
    }

}
