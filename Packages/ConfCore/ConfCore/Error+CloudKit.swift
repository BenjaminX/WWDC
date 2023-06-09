//
//  Error+CloudKit.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 25/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKit
import OSLog

extension Error {

    var isCloudKitConflict: Bool {
        guard let effectiveError = self as? CKError else { return false }

        return effectiveError.code == .serverRecordChanged
    }

    func resolveConflict(with resolver: (CKRecord, CKRecord) -> CKRecord?) -> CKRecord? {
        guard let effectiveError = self as? CKError else {
            Logger.default.fault("resolveConflict called on an error that was not a CKError. The error was \(String(describing: self), privacy: .public)")
            return nil
        }

        guard effectiveError.code == .serverRecordChanged else {
            Logger.default.fault("resolveConflict called on a CKError that was not a serverRecordChanged error. The error was \(String(describing: effectiveError), privacy: .public)")
            return nil
        }

        guard let clientRecord = effectiveError.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord else {
            Logger.default.fault("Failed to obtain client record from serverRecordChanged error. The error was \(String(describing: effectiveError), privacy: .public)")
            return nil
        }

        guard let serverRecord = effectiveError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            Logger.default.fault("Failed to obtain server record from serverRecordChanged error. The error was \(String(describing: effectiveError), privacy: .public)")
            return nil
        }

        return resolver(clientRecord, serverRecord)
    }

    @discardableResult func retryCloudKitOperationIfPossible(_ log: Logger? = nil, in queue: DispatchQueue = .main, with block: @escaping () -> Void) -> Bool {
        let effectiveLog = log ?? .default

        guard let effectiveError = self as? CKError else { return false }

        guard let retryDelay = effectiveError.retryAfterSeconds else {
            effectiveLog.error("Error is not recoverable")
            return false
        }

        effectiveLog.error("Error is recoverable. Will retry after \(retryDelay) seconds")

        queue.asyncAfter(deadline: .now() + retryDelay) {
            block()
        }

        return true
    }

}
