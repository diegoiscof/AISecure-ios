//
//  ProtectedPropertyQueue.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

enum ProtectedPropertyQueue {

    static let logLevel = DispatchQueue(
        label: "aisecure-protected-log-level",
        attributes: .concurrent
    )

    static let session = DispatchQueue(
        label: "aisecure-protected-session",
        attributes: .concurrent
    )
}
