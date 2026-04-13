/*
 * Copyright (c) 2026 Clemens Lang
 * SDPX-License-Identifier: BSD-2-Clause
 */

import Foundation
import Logging
import NetworkInterfaceChangeMonitoring
import NetworkInterfaceInfo
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
    case noSuchKey(String)
    case typeMismatch
    case updateFailed
}

let APP_ID = "de.neverpanic.dnsguard";

let logger = Logger(label: APP_ID)

private func resetDNS(sc_path: String, domains: [String]) async throws {
    let store = SCDynamicStoreCreate(nil, APP_ID as CFString, nil, nil);
    guard let store = store else {
        throw DNSGuardError.storeCreationFailed
    }

    let d = SCDynamicStoreCopyValue(store, sc_path as CFString);
    guard let d = d else {
        throw DNSGuardError.noSuchKey(sc_path)
    }
    guard let dict = d.mutableCopy() as? NSMutableDictionary else {
        throw DNSGuardError.typeMismatch
    }

    dict[kSCPropNetDNSSupplementalMatchDomains] = domains as NSArray

    if !SCDynamicStoreSetValue(store, sc_path as CFString, dict) {
        throw DNSGuardError.updateFailed
    }
}


private func main() async throws -> Int32 {
    var maybe_config: DNSGuardConfig? = nil;
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

    for try await change in NetworkInterface.changes(coalescingPeriod: 1) {
        switch change.nature {
            case .added, .modified:
                if config.interfaces.contains(change.interface.name) && change.interface.address?.family == .link {
                    let mod = switch change.nature {
                        case .added:
                            "came up"
                        case .modified:
                            "was modified"
                        case .removed:
                            "was shut down"
                    }
                    logger.info("\(change.interface.name) \(mod), resetting DNS")
                    do {
                        try await resetDNS(sc_path: config.sc_path, domains: config.domains)
                        logger.info("DNS supplementalMatchDomains successfully set to \(config.domains)")
                    } catch {
                        logger.warning("Failed to reset DNS", metadata: ["error": "\(error)"])
                    }
                }
            default:
                break
        }
    }

    return EXIT_SUCCESS
}

exit(try await main())
