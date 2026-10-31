# m4b playback bench

Plays an m4b through AudioStreaming as a local file (per extension) and as a stream (per
server `Content-Type`), with the moov atom after and before the audio data.

1. Make the test files: `zsh bench/m4b/make_m4b.sh <scratch>/m4b`
2. Serve them: `python3 -I bench/m4b/serve.py <scratch>/m4b 8765`
3. Run on a simulator you created (see CLAUDE.md "Simulator automation"):
   ```
   xcodebuild test -project Amperfy.xcodeproj -scheme Amperfy \
     -destination 'platform=iOS Simulator,id=<sim id>' \
     -only-testing:AmperfyKitTests/M4bPlaybackBench \
     -derivedDataPath <scratch>/dd-sim > <scratch>/bench.log 2>&1
   grep "^BENCH" <scratch>/bench.log
   ```
   The player volume is 0, so nothing is audible.

To try an AudioStreaming change, edit
`<scratch>/dd-sim/SourcePackages/checkouts/AudioStreaming/AudioStreaming/Streaming/Helpers/AudioFileType.swift`
and add `-skipPackageUpdates -disableAutomaticPackageResolution` to the `xcodebuild` command,
or Xcode resets the checkout.
