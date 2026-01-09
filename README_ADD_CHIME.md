Add a bundled chime audio file for Yogik

The app looks for a bundled audio file named `chime.wav`, `chime.mp3`, or `chime.m4a` at runtime and will use `AVAudioPlayer` to play it. If no bundled file is found the app falls back to a short system sound.

To add a chime:

1. Put your audio file into the Xcode project (drag it into the Project navigator). Make sure "Copy items if needed" is checked and the target `Yogik` is selected so the file is bundled with the app.

2. Name the file `chime.wav`, `chime.mp3`, or `chime.m4a` (one of these filenames) so the app can find it automatically.

3. Build and run on a device. Simulator may not always play system sounds as expected; for best results test chime playback on a real device.

If you'd like, I can add a default chime audio file into the project for you (you will need to confirm you permit embedding that file).