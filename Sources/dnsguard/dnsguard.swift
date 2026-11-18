/*
 * Copyright (c) 2026 Clemens Lang
 * SDPX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Logging
import SystemConfiguration

struct DNSGuardConfig: Decodable {
    enum CodingKeys: String, CodingKey {
        case interfaces, domains
        case sc_path = "sc-path"
    }

    let interfaces: [String]
    let sc_path: String
    let domains: [String]
}

enum DNSGuardError: Error {
    case storeCreationFailed
    case storeNotificationsFailed
}

let APP_ID = "de.neverpanic.dnsguard";

let logger = Logger(label: APP_ID)

var maybe_config: DNSGuardConfig? = nil;

let handleChange: SCDynamicStoreCallBack = {
    (store, changedKeys, _) -> Void in
    logger.info("SCDynamicStore keys changed: \(changedKeys)")
    let config = maybe_config!

    guard let keys = changedKeys as? [String] else {
        logger.warning("Changed keys are not an array of Strings")
        return
    }

    for key in keys {
        if key != config.sc_path {
            logger.info("Ignoring change in unwatched key \(key)")
            continue
        }

        let d = SCDynamicStoreCopyValue(store, config.sc_path as CFString)
        guard let d = d else {
            logger.info("\(key) was removed")
            continue
        }

        guard let dict = d.mutableCopy() as? NSMutableDictionary else {
            logger.warning("\(key) was modified, but it is not a dictionary as expected")
            continue
        }

        let expected_domains = config.domains as NSArray
        guard let current_domains = dict[kSCPropNetDNSSupplementalMatchDomains] as? NSArray else {
            logger.warning("\(key)'s \(kSCPropNetDNSSupplementalMatchDomains) value is not an array: \(String(describing: dict[kSCPropNetDNSSupplementalMatchDomains]))")
            continue
        }

        if current_domains == expected_domains {
            logger.info("\(key)'s \(kSCPropNetDNSSupplementalMatchDomains) value (\(current_domains)) already matches the expected value (\(expected_domains))")
            continue
        }

        dict[kSCPropNetDNSSupplementalMatchDomains] = expected_domains
        if !SCDynamicStoreSetValue(store, config.sc_path as CFString, dict) {
            logger.error("Failed to update \(key)'s \(kSCPropNetDNSSupplementalMatchDomains) value")
        }
    }
}

@MainActor
private func main() async throws -> Int32 {
    do {
        let config_dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let config_file = config_dir.appendingPathComponent(APP_ID).appendingPathComponent("config.json")
        let config_data = try Data(contentsOf: config_file, options: .mappedIfSafe)
        maybe_config = try! JSONDecoder().decode(DNSGuardConfig.self, from: config_data)
    } catch {
        logger.error("Failed to read config file", metadata: ["error": "\(error)"])
        return EXIT_FAILURE
    }

    let config = maybe_config!

    let store = SCDynamicStoreCreate(nil, APP_ID as CFString, handleChange, nil)
    guard let store = store else {
        throw DNSGuardError.storeCreationFailed
    }

    if !SCDynamicStoreSetNotificationKeys(store, [config.sc_path as CFString] as CFArray, nil) {
        throw DNSGuardError.storeNotificationsFailed
    }

    if !SCDynamicStoreSetDispatchQueue(store, DispatchQueue.main) {
        throw DNSGuardError.storeNotificationsFailed
    }

    logger.info("Monitoring \(config.sc_path) for changes...")

    // Trigger an initial notification on startup to make sure the value is as expected
    if !SCDynamicStoreNotifyValue(store, config.sc_path as CFString) {
        throw DNSGuardError.storeNotificationsFailed
    }

    // Never returns
    Dispatch.dispatchMain()
}

exit(try await main())
