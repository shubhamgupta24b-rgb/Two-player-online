# Play Store Release Checklist

## Repository status

This project has a separate `release/play-store-hardening` branch for the Play Store release work.

### Required before production

1. Choose the final app name.
2. Choose and confirm the permanent Android application ID/package name. Do not change it after publishing.
3. Configure production authentication. The current client uses development guest tokens; do not publish a public server with `AUTH_MODE=dev`.
4. Deploy the server behind HTTPS/WSS.
5. Configure MongoDB if persistent user data is required.
6. Create a release/upload keystore and keep the private key backed up securely.
7. Add these GitHub Actions secrets:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`
8. Run the release workflow with the production HTTPS server URL.
9. Upload the generated `app-release.aab` to Play Console internal testing first.
10. Complete Play Console App content, Data safety, content rating, target audience, and store listing.
11. Publish a publicly accessible HTTPS privacy policy and link it both in Play Console and inside the app.
12. Test the production build on multiple physical Android devices before production rollout.

## Important security rule

Never commit:
- `key.properties`
- `.jks` / `.keystore` files
- Firebase service-account JSON
- passwords, API secrets, or private keys

## Current release workflow

The release workflow:
- requires an HTTPS server URL
- runs Flutter tests and analysis
- creates a signed Android App Bundle
- requires release-signing GitHub secrets
- uploads the AAB as a workflow artifact

## Current known blocker

The app currently implements development guest authentication. A public production server must use a real production authentication mechanism before launch.

## Google Play target API

For a new app submission in 2026, configure the final Android build to target API 36 or higher, subject to the current Google Play requirements at submission time.
