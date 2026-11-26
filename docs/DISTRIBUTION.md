# Distribution

1. Run unit tests and the isolated engine integration test.
2. Build each supported architecture with a Developer ID Application identity using `LUMA_SIGNING_IDENTITY`.
3. Verify nested code signatures, the bundle, and all embedded dependency licenses.
4. Install into `/Applications` on a clean Mac; approve the SMAppService daemon through macOS. Do not bypass approval or signature checks.
5. Complete the gateway acceptance plan, including recovery and uninstall cases.
6. Create a ZIP with `ditto -c -k --keepParent dist/Luma.app Luma.zip`.
7. Submit to Apple's notarization service using the maintainer's own credentials and then staple the accepted ticket. No credentials belong in the repository.
8. Publish artifacts, source, third-party notices, checksums, and accurate platform/test coverage in a GitHub release.

A local ad-hoc signed build is a development artifact. Do not label it notarized or claim its privileged-helper installation is verified when only the user-space engine has been tested.

Before choosing a permanent public bundle ID/domain, establish ownership of the namespace. `app.luma.*` is a development identifier, not a claim of domain ownership. The working product name also needs an availability check before a public launch.

For updates, increment CFBundleVersion, stop sharing and the engine, unregister the old helper, quit, then replace the app bundle atomically with the verified new bundle. Keep a recoverable previous build. Register the new helper through ServiceManagement; never weaken launch constraints to work around stale registration.
