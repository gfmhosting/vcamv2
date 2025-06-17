# StripeVCAM Bypass

A lightweight iOS jailbreak tweak that bypasses Stripe's liveness KYC verification by replacing the camera feed with selected media.

## Features

- Replace camera feed with custom images from your photo library
- Double-tap volume buttons to activate the overlay
- Debug logging system for troubleshooting
- Works specifically on iPhone 7 running iOS 13.3.1 with checkra1n jailbreak

## Installation

### Option 1: Install from .deb file

1. Download the latest `.deb` file from the [GitHub Actions](../../actions) artifacts
2. Transfer the `.deb` file to your device using SCP:
   ```bash
   scp StripeVCAMBypass.deb root@[your-device-ip]:/tmp/
   ```
3. SSH into your device:
   ```bash
   ssh root@[your-device-ip]
   ```
4. Install the package:
   ```bash
   dpkg -i /tmp/StripeVCAMBypass.deb
   ```
5. Respring your device:
   ```bash
   killall -9 SpringBoard
   ```

### Option 2: Build from source

1. Clone this repository
2. Make sure you have [Theos](https://theos.dev/docs/installation) installed
3. Run `make package` to build the package
4. Run `make install` to install on your device (requires proper device configuration in Theos)

## Usage

1. Open any app that uses the camera (like Stripe KYC verification)
2. Double-tap either volume button to bring up the overlay
3. Tap "Select Image" to choose an image from your photo library
4. The selected image will now replace the camera feed in all apps

### Debug Logs

If you encounter issues:

1. Open the overlay by double-tapping a volume button
2. Tap "Debug Logs" to view the logs
3. You can clear logs by tapping "Clear"

## Configuration

You can configure the tweak in the Settings app:

- Enable/Disable the tweak
- Enable/Disable debug logging

## Building with GitHub Actions

This project uses GitHub Actions to automatically build the tweak. Each push to the repository will trigger a build, and the resulting `.deb` file will be available as an artifact.

## License

This project is open source and available under the [MIT License](LICENSE).

## Credits

- [Theos](https://theos.dev/) - iOS development toolkit
- [Randomblock1/theos-action](https://github.com/Randomblock1/theos-action) - GitHub Action for Theos 