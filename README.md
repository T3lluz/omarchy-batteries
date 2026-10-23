# Peripheral Battery

An Omarchy bar widget for the battery in your mouse and other wireless
peripherals. The bar shows the device's icon and level:

- **On the USB cable**: a charging bolt next to the level, until it reads 100%.
- **On the 2.4 GHz dongle or Bluetooth**: the level, turning the theme's
  urgent color when it drops below your low-battery threshold.
- **Asleep**: the last level it reported, dimmed, so the bar does not blank
  every time the mouse naps.

Plugging the cable in or out updates the bar within a second or two (it
listens to udev), and you get a notification once per dip when a device runs
low.

Click it for a panel listing every battery-powered peripheral with a level
bar, its charging state and how it is connected. Click a device to show it in
the bar instead of the mouse.

## Supported devices

| Source | Devices |
|---|---|
| Built in, HID | Glorious Model O, O-, D and D- Wireless, on the cable and on the dongle |
| Built in, HID | HyperX Cloud Alpha Wireless |
| UPower | Bluetooth mice, keyboards and headsets, Logitech Lightspeed/Unifying (HID++), PlayStation and Switch controllers, Apple Magic devices, Wacom tablets |
| openrazer | Razer wireless mice and keyboards, when the openrazer driver is installed |
| HeadsetControl | SteelSeries, Logitech, Corsair, HyperX and other headsets, when `headsetcontrol` is installed |

If one device is reported by two sources, the first in this table wins.

The Glorious reader speaks the protocol from
[korkje/mow](https://github.com/korkje/mow) and
[gloriousctl](https://github.com/ibericode/gloriousctl), and the HyperX one the
protocol from
[streamdeck-hyperx-caw-battery](https://github.com/T3lluz/streamdeck-hyperx-caw-battery-Linux).
It was first written for
[streamdeck-glorious-model-o-battery-Linux](https://github.com/T3lluz/streamdeck-glorious-model-o-battery-Linux).
Here it talks to `/dev/hidraw` through the kernel's ioctls directly, so it
needs only Python's standard library, no hidapi.

## Install

```sh
omarchy plugin add https://github.com/T3lluz/omarchy-peripheral-battery.git --enable
```

Glorious and HyperX devices need read access to their HID node. Click the bar
icon and press **Grant access** (it asks for your password once), or run:

```sh
sudo ~/.config/omarchy/plugins/io.github.t3lluz.peripheral-battery/bin/peripheral-battery install-udev
```

That installs `udev/70-omarchy-peripheral-battery.rules`, which gives the
logged-in user (`uaccess`) access to those devices only.

## Use

| Input | Action |
|---|---|
| Click | Open the panel |
| Middle click | Refresh now |
| `↑` `↓` `Enter` in the panel | Pick the device shown in the bar |
| `r` | Refresh |
| `c` | Settings |

Settings live in the panel (gear icon) and in the widget's entry in
`~/.config/omarchy/shell.json`:

| Key | Default | |
|---|---|---|
| `device` | `""` | Device id for the bar. Empty picks the first mouse. |
| `showPercent` | `true` | Show the level next to the icon |
| `hideWhenEmpty` | `true` | Hide the widget when nothing is found |
| `lowThreshold` | `20` | Low battery level, in percent |
| `notifyLow` | `true` | Notify when a device crosses the threshold |
| `refreshIntervalSec` | `30` | Poll interval; 5 s while the panel is open |

## Command line

```sh
bin/peripheral-battery list     # human readable
bin/peripheral-battery probe    # the JSON the widget reads
```

```
Glorious Model O Wireless          mouse       83% ⚡  charging, usb via glorious
```

## Tests

```sh
node tests/model.test.js
python3 -m unittest discover tests
```

## License

MIT. Not affiliated with Glorious, HyperX or Razer.
