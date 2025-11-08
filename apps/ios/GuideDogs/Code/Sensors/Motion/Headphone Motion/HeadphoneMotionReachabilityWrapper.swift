//
//  HeadphoneMotionReachabilityWrapper.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

// `HeaphoneMotionManager` is only available iOS 14.4+
//
// This is a wrapper class which should be removed
// once support for iOS < 14.4 is removed
//
// This is a temporary class
class HeadphoneMotionManagerReachabilityWrapper {

    // MARK: Parameters

    /// The underlying reachability manager.  This is always available on
    /// supported versions of iOS, so it is non-optional.  The previous
    /// implementation contained conditional code paths for older iOS
    /// versions; these have been removed now that we require iOS 15.
    let headphoneMotionManagerReachability: DeviceReachability

    // MARK: Initialization

    init() {
        // Directly initialize the reachability manager.  No availability
        // checks are necessary because the minimum supported iOS version
        // guarantees its existence.
        headphoneMotionManagerReachability = HeadphoneMotionManagerReachability()
    }
}

extension HeadphoneMotionManagerReachabilityWrapper: DeviceReachability {

    func ping(timeoutInterval: TimeInterval, completion: @escaping ReachabilityCompletion) {
        // Delegate the ping call to the underlying reachability manager.
        headphoneMotionManagerReachability.ping(timeoutInterval: timeoutInterval, completion: completion)
    }

}
