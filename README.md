# dnsguard

This is a small daemon written in Swift that monitors a configurable list of
network interfaces for changes, and ensures that the `SupplementalMatchDomains`
setting of a configurable system configuration object is set to a specific value.

This is helpful for VPNs that configure a set of domains to use for DNS
resolution that does not work for you, e.g., if the VPN connection pushes an
empty value, leading to its DNS servers to be used for all lookups and thereby
breaking DNS lookup for your home network.

An example configuration is available in `config.json.example`. Copy it to
`/var/root/Library/Application Support/de.neverpanic.dnsguard/config.json` and
edit it as required, then build and install the binary, the launchd
LaunchDaemon, and enable it:

```sh
$ swift build --configuration release
$ sudo install -m 755 .build/release/dnsguard /usr/local/bin/dnsguard
$ sudo install -m 644 de.neverpanic.dnsguard.plist /Library/LaunchDaemons/
$ sudo launchctl load -w /Library/LaunchDaemons/de.neverpanic.dnsguard.plist
```

You'll find log files in `/var/log/dnsguard.log` and `/var/log/dnsguard-error.log`.

## License

This project is licensed under the BSD-2-Clause license.
