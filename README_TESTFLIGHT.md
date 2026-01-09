TestFlight upload instructions for Yogik

This project includes helper files to create an archive and upload an `.ipa` to App Store Connect for TestFlight.

Files added:
- `ExportOptions.plist` — used by `xcodebuild -exportArchive` to export an App Store build.
- `scripts/upload_to_testflight.sh` — a small zsh wrapper that archives, exports, and uploads via `xcrun altool`.

Quick GUI method (recommended for first upload)
1. Open the project in Xcode:
   ```bash
   open Yogik.xcodeproj
   ```
2. In Xcode, increment the build number: select project → target → General → Build.
3. Select your Team in Signing & Capabilities and ensure automatic signing is enabled.
4. Choose a Generic iOS Device (or Any Device) as the run destination.
5. Product → Archive. When the archive finishes the Organizer will open.
6. Select the archive → Distribute App → App Store Connect → Upload.

Command-line method
1. Create an app-specific password for your Apple ID: https://appleid.apple.com -> Security -> App-Specific Passwords -> Generate Password.
2. From the project root run:
   ```bash
   chmod +x scripts/upload_to_testflight.sh
   ./scripts/upload_to_testflight.sh YOUR_APPLE_ID APP_SPECIFIC_PASSWORD
   ```
3. Wait for App Store Connect processing. The build will appear under TestFlight once processed.

Notes
- The first time you distribute an app externally via TestFlight it requires a Beta App Review. Internal testers (members of your App Store Connect team) can be invited immediately.
- `xcrun altool` requires an app-specific password. Alternatively, you can use the Transporter app (GUI) or Apple Transporter CLI.
- If you prefer CI upload (e.g. GitHub Actions or Fastlane), I can generate a `Fastfile` or CI workflow for you.
