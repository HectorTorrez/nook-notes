# Releasing Blink

Releases are built, signed, notarized, and stapled locally. There is no hosted
CI/CD pipeline; run the test suite before you start.

## 1. Test

```bash
./apps/macos/scripts/test.sh
```

## 2. Prepare credentials

You need a **Developer ID Application** certificate in your login keychain and
an app-specific password for notarization.

Store the notarization credentials once:

```bash
xcrun notarytool store-credentials "blink-notary" \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

## 3. Build and notarize

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="blink-notary" \
./apps/macos/scripts/release.sh
```

The script builds a Release app, signs it with the hardened runtime, creates
`apps/macos/dist/Blink.zip`, submits it with `notarytool --wait`, staples the
ticket, and recreates the zip.

If you prefer not to store a keychain profile, set `APPLE_ID`, `TEAM_ID`, and
`APP_SPECIFIC_PASSWORD` instead of `NOTARY_PROFILE`.

## 4. Publish

1. Bump `MARKETING_VERSION` in `apps/macos/Blink.xcodeproj/project.pbxproj`.
2. Upload `apps/macos/dist/Blink.zip` to a GitHub release.
3. Paste the release notes and link the download from the landing page.

## Notes

- `apps/macos/scripts/install.sh` is for local installs and does not notarize.
- Ad-hoc or unnotarized builds trigger Gatekeeper on other Macs. Users can
  right-click **Blink.app → Open** once, but a notarized release is preferred.
- The app uses the hardened runtime (`ENABLE_HARDENED_RUNTIME = YES`).
