# LCD HR 245

**English** | [简体中文](README.zh-CN.md)

A Connect IQ watch face for the Garmin Forerunner 245 and 245 Music. White seven-segment digits show the time in 24-hour format, with the date in Chinese above them. A green graph shows the past hour of heart rate readings, with your current heart rate on the right and battery level below.

![Forerunner 245 simulator showing 10:08, a heart rate of 68 BPM, and 82% battery](previews/v1.0.8-fr245.png)

## Install v1.0.8

1. Download and unzip the [USB installation package](https://github.com/cfmcgrady/garmin-lcd-watchface/raw/refs/tags/v1.0.8/dist/FR245-LCD-HR-v1.0.8-USB.zip).
2. Connect the watch to your computer with a USB data cable. Copy `LcdHr245.prg` to the `GARMIN/APPS/` folder on the watch.
3. Eject the watch and disconnect the cable. On the watch, hold **UP**, open **Watch Face**, select **LCD HR 245**, and apply it.

The package contains the original signed `LcdHr245.prg` (16,348 bytes). Its SHA-256 checksum is `20e5818e7dbbc78b62879b70b7b26b7fddea7281e1451d61a32813b47ce6cace`.

## Heart rate and battery use

The watch face reads the past hour of heart rate history every five minutes. Each point on the graph is a one-minute average. Invalid readings and long gaps in sampling break the line.

The current heart rate updates once a minute. Raising your wrist can trigger an extra reading if at least 15 seconds have passed since the last update. When a live reading is unavailable, the watch face uses the most recent valid reading for up to three minutes after it was recorded. It then shows `--`.

Version 1.0.8 caches the watch face image when enough memory is available to avoid redrawing it on every update. The effect on battery life has yet to be measured on a physical watch.

## Build and verify

The v1.0.8 source was reconstructed from an earlier copy of the project using the final layout, refresh logic, test records, and original signed program. With Connect IQ SDK 9.2.0 and a new test signing key, builds for both `fr245` and `fr245m` matched the original byte for byte in every section outside the developer signature, including the Monkey C bytecode, fonts, and images. All 13 tests passed on the Forerunner 245 simulator. The layout check covered all 1,440 times of day.

Install the Garmin Connect IQ SDK and use the SDK Manager to download device support for your model. To build for the Forerunner 245, run this command from the project root with your own Connect IQ developer signing key.

```sh
python3 tools/build.py --sdk /path/to/connectiq-sdk --key /path/to/developer.der --device fr245
```

The output is `build/LcdHr245.prg`. For the 245 Music, use `--device fr245m`. The output is `build/LcdHr245Music.prg`.

The bitmap fonts are included. To regenerate them, run `tools/make_assets.py` with Pillow and the Noto Sans CJK Bold and DejaVu Sans Condensed Bold system fonts installed. The script also uses the bundled DSEG and Roboto Condensed fonts.

To run the simulator tests, add `--tests` to the build command above, start the Connect IQ Simulator, and run the first command below using the SDK's `monkeydo` tool. The second command checks the time layout and requires Python and Pillow.

```sh
monkeydo build/LcdHr245Tests.prg fr245 -t
python3 tools/check_time_layout.py
```

## License

The project's original code is licensed under the [Apache License 2.0](LICENSE). See the [font and icon credits](licenses/README.md) for their licenses.
