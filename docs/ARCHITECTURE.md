# Architecture

```
Discord ── SOCKS ─────────────────────┐
Discord updater ── HTTP CONNECT ──────┤
                                     ▼
                              local ByeDPI ── Internet
                                     ▲
PS5 ── existing router LAN ── Mac ── tun2socks
                                source-scoped PF
```

## Components

- `LumaApp`: SwiftUI dashboard, menu bar, validation, diagnostics, per-app launch environment, console instructions.
- `LumaAgent`: unprivileged supervisor and HTTPS CONNECT bridge. Bundled `ciadpi` is restarted with bounded backoff. Registered as an on-demand user launch agent; not automatically started at login.
- `LumaGateway`: ServiceManagement launch daemon, XPC authorization, validated single-client PF plan, tunnel lifecycle, health watchdog, cleanup and crash recovery.
- `LumaCore`: strict IPv4 and HTTP request parsing, network discovery, command execution without shell evaluation, shared XPC protocol and data structures.

## Addresses and lifecycle

There are no hard-coded user addresses or usernames. The actual default interface, IPv4 address, mask, and router are discovered at runtime. The selected console must have a private unicast address on the same subnet, distinct from the Mac, router, network, and broadcast address.

The app engine listens on loopback ports 17881/17882. The gateway chooses an unused utun180–utun199 interface. It redirects only TCP and UDP sourced by the selected console and destined outside the local subnet. Other console protocols use a source-scoped NAT rule. The underlying system default route is left intact, avoiding a local proxy routing loop.

Stopping console sharing leaves Mac access available. Stopping the engine is blocked in the UI while its gateway is active. Normal quit asks before disconnecting active services. The daemon health watchdog cleans up an abandoned session after the app heartbeat expires.

## Scope

No transparent interception of arbitrary Mac applications, no system-wide proxy toggle, no router credential handling, no remote control of the PS5, no automated host-file or Discord-settings modifications. Discord must be started from the app for its native updater environment to take effect.

Product, executable and service names consistently use Luma. No device profile ships with the app; preferences are local to each macOS account.
