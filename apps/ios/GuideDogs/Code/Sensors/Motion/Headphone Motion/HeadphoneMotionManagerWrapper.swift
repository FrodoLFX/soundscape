//
//  HeadphoneMotionManagerWrapper.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import Combine

// `HeaphoneMotionManager` is only available iOS 14.4+
//
// This is a wrapper class which should be removed
// once support for iOS < 14.4 is removed
class HeadphoneMotionManagerWrapper {
    
    typealias UserHeadingDevice = UserHeadingProvider & Device
    
    // MARK: Properties
    
    private let headphoneMotionManager: UserHeadingDevice?
    private var subscriber: AnyCancellable?
    private(set) var status: CurrentValueSubject<HeadphoneMotionStatus, Never>
    // `UserHeadingProvider` delegate
    weak var headingDelegate: UserHeadingProviderDelegate?
    // `Device` delegate
    weak var deviceDelegate: DeviceDelegate?

    // MARK: Initialization

    /// Initialize a wrapper for the headphone motion manager.  Since the
    /// minimum supported iOS version is now 15, the underlying
    /// `HeadphoneMotionManager` will always be available.  The previous
    /// implementation contained conditional code paths for older iOS
    /// versions; these have been removed.
    convenience init() {
        let manager = HeadphoneMotionManager()
        self.init(headphoneMotionManager: manager)
    }

    /// Initialize a wrapper for the headphone motion manager with an
    /// explicit identifier and name.  The underlying manager is
    /// unconditionally available on supported systems.
    convenience init(id: UUID, name: String) {
        let manager = HeadphoneMotionManager(id: id, name: name)
        self.init(headphoneMotionManager: manager)
    }
    
    private init(headphoneMotionManager: UserHeadingDevice?) {
        // The underlying `CMHeadphoneMotionManager` is available from iOS 14.4
        // onward and our minimum supported version is iOS 15.  Cast the
        // provided device to `HeadphoneMotionManager` when possible.  If the
        // cast fails we treat the device as unavailable.
        if let headphoneMotionManager = headphoneMotionManager as? HeadphoneMotionManager {
            // Initialize headphone motion manager
            self.headphoneMotionManager = headphoneMotionManager

            // Initialize status with the current value
            let value = headphoneMotionManager.status.value
            self.status = .init(value)

            // Listen for and publish new values of `status`
            subscriber = headphoneMotionManager.status
                .receive(on: RunLoop.main)
                .sink { [weak self] newValue in
                    guard let self = self else { return }
                    // Update status
                    self.status.value = newValue
                }
        } else {
            // `CMHeadphoneMotionManager` is not available, mark as unavailable
            self.headphoneMotionManager = nil
            self.status = .init(.unavailable)
        }

        // After `self` has initialized, initialize delegates
        self.headphoneMotionManager?.headingDelegate = self
        self.headphoneMotionManager?.deviceDelegate = self
    }
    
}

extension HeadphoneMotionManagerWrapper: UserHeadingProvider {
    
    // MARK: Properties
    
    var id: UUID {
        headphoneMotionManager?.id ?? UUID()
    }
    
    var accuracy: Double {
        return headphoneMotionManager?.accuracy ?? 0.0
    }
    
    // MARK: User Heading Updates
    
    func startUserHeadingUpdates() {
        headphoneMotionManager?.startUserHeadingUpdates()
    }
    
    func stopUserHeadingUpdates() {
        headphoneMotionManager?.stopUserHeadingUpdates()
    }
    
}

extension HeadphoneMotionManagerWrapper: UserHeadingProviderDelegate {
    
    func userHeadingProvider(_ provider: UserHeadingProvider, didUpdateUserHeading heading: HeadingValue?) {
        headingDelegate?.userHeadingProvider(self, didUpdateUserHeading: heading)
    }
    
}

extension HeadphoneMotionManagerWrapper: Device {
    
    // MARK: Properties
    
    var name: String {
        headphoneMotionManager?.name ?? ""
    }
    
    var model: String {
        headphoneMotionManager?.model ?? GDLocalizationUnnecessary("Apple AirPods")
    }
    
    var type: DeviceType {
        headphoneMotionManager?.type ?? .apple
    }
    
    var isConnected: Bool {
        headphoneMotionManager?.isConnected ?? false
    }
    
    var isFirstConnection: Bool {
        headphoneMotionManager?.isFirstConnection ?? false
    }
    
    // MARK: Device
    
    static func setupDevice(callback: @escaping DeviceCompletionHandler) {
        // The headphone motion manager is always available on the minimum
        // supported iOS version.  Set up the underlying manager and wrap it
        // directly.
        HeadphoneMotionManager.setupDevice { result in
            switch result {
            case .success(let device):
                let manager = device as? HeadphoneMotionManager
                let wrapper = HeadphoneMotionManagerWrapper(headphoneMotionManager: manager)
                callback(.success(wrapper))
            case .failure(let error):
                callback(.failure(error))
            }
        }
    }
    
    func connect() {
        headphoneMotionManager?.connect()
    }
    
    func disconnect() {
        headphoneMotionManager?.disconnect()
    }
    
}

extension HeadphoneMotionManagerWrapper: DeviceDelegate {
    
    func didConnectDevice(_ device: Device) {
        deviceDelegate?.didConnectDevice(self)
    }
    
    func didFailToConnectDevice(_ device: Device, error: DeviceError) {
        deviceDelegate?.didFailToConnectDevice(self, error: error)
    }
    
    func didDisconnectDevice(_ device: Device) {
        deviceDelegate?.didDisconnectDevice(self)
    }
    
}
