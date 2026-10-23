# Batteries

An Omarchy bar widget for every battery on and around your computer: the
laptop, AirPods, and your mouse, keyboard, headset, controller and phone.

The bar shows the batteries you pick, each as an icon and level, with a
charging bolt while it charges. Pick what it shows from the gear in the
panel, the same way as in
[Server Dashboard](https://github.com/T3lluz/omarchy-server-dashboard):

- Laptop battery level
- Laptop charge or discharge rate, in watts
- Laptop time left, or time to full
- AirPods (the emptier bud) and the AirPods case
- Any peripheral, one toggle each (every mouse until you pick)
- Percentages on or off

Click it for the panel:

- **Laptop**: level with the charge limit marked, charging or on battery with
  the time left or time to full, the rate in watts, energy in Wh, health
  against the design capacity, cycle count, charge limit, and power source.
- **AirPods**: each bud and the case with its level, charging and in-ear
  state, or an AirPods Max's single battery. Last seen levels stay, dimmed,
  after they go back in the case.
- **Devices**: every peripheral with a level bar, its state and how it is
  connected (USB cable, 2.4 GHz or Bluetooth). Click one to show or hide it in
  the bar.

Plugging a cable or the charger in or out refreshes within a second or two
(the widget listens to udev), as does any change librepods reports for your
AirPods. You get one notification each time a peripheral or your AirPods drop
below the low battery threshold. The laptop keeps Omarchy's own warning.

The icons are [Tabler Icons](https://tabler.io/icons) drawn as theme-colored
strokes, so they follow your theme and do not depend on the Nerd Font build.
The AirPods outline is the one from
[omapods](https://github.com/thisisgm/omapods), picked by model (AirPods, Pro or
Max).

## Supported batteries

| Source | Batteries |
|---|---|
| sysfs + UPower | The laptop's own battery (two-battery laptops are combined) |
| librepods | AirPods, AirPods Pro and AirPods Max, through the daemon [omapods](https://github.com/thisisgm/omapods) installs |
| Built in, HID | Glorious Model O, O-, D and D- Wireless, on the cable (charging) and on the dongle |
| Built in, HID | HyperX Cloud Alpha Wireless |
| UPower | Bluetooth mice, keyboards and headsets, Logitech Lightspeed/Unifying (HID++), PlayStation and Switch controllers, Apple Magic devices, Wacom tablets, UPSes |
| openrazer | Razer wireless mice and keyboards, when the openrazer driver is installed |
| HeadsetControl | SteelSeries, Logitech, Corsair, HyperX and other headsets, when `headsetcontrol` is installed |
| libimobiledevice | An iPhone or iPad on USB |
| KDE Connect | Phones paired with KDE Connect |

If one device is reported by two sources, the first in this table wins. The
librepods reading of your AirPods beats BlueZ's single headset level.

The Glorious reader speaks the protocol from
[korkje/mow](https://github.com/korkje/mow) and
[gloriousctl](https://github.com/ibericode/gloriousctl), and the HyperX one the
protocol from
[streamdeck-hyperx-caw-battery](https://github.com/T3lluz/streamdeck-hyperx-caw-battery-Linux).
It was first written for
[streamdeck-glorious-model-o-battery-Linux](https://github.com/T3lluz/streamdeck-glorious-model-o-battery-Linux).
It talks to `/dev/hidraw` through the kernel's ioctls directly, so the reader
needs only Python's standard library.

## Install

```sh
omarchy plugin add https://github.com/T3lluz/omarchy-batteries.git --enable
```

Glorious and HyperX devices need read access to their HID node. Click the bar
icon and press **Grant access** (it asks for your password once), or run:

```sh
sudo ~/.config/omarchy/plugins/io.github.t3lluz.batteries/bin/batteries install-udev
```

That installs `udev/70-omarchy-batteries.rules`, which gives the logged-in
user (`uaccess`) access to those devices only.

AirPods need the librepods daemon from omapods running; nothing else is
needed for them.

## Use

| Input | Action |
|---|---|
| Click | Open the panel |
| Middle click | Refresh now |
| `r` in the panel | Refresh |
| `c` in the panel | What the bar shows, low battery |

Settings are saved in the widget's entry in `~/.config/omarchy/shell.json`:

| Key | Default | |
|---|---|---|
| `barLaptop` | `true` | Laptop level in the bar |
| `barLaptopRate` | `false` | Laptop charge or discharge rate (W) |
| `barLaptopTime` | `false` | Laptop time left or to full |
| `barAirpods` | `true` | AirPods, the emptier bud |
| `barAirpodsCase` | `false` | AirPods case |
| `barDevices` | `null` | Peripheral ids for the bar; `null` shows every mouse |
| `barPercent` | `true` | Percentages next to the icons |
| `lowThreshold` | `20` | Low battery level, in percent |
| `notifyLow` | `true` | Notify when a peripheral or AirPods cross it |
| `refreshIntervalSec` | `30` | Poll interval; 10 s with rate or time in the bar, 5 s while the panel is open |

## Command line

```sh
bin/batteries list     # human readable
bin/batteries probe    # the JSON the widget reads
```

```
Laptop (BAT0)                      laptop      89%  discharging, 51.9 W, 1h 00m left, health 75%, limit 90%
AirPods Pro                        airpods     70%  L 80% R 70% case 50%⚡, connected
Glorious Model O Wireless          mouse       83% ⚡  charging, usb via glorious
```

## Development

```sh
node tests/model.test.js
python3 -m unittest discover tests
python3 scripts/fetch-icons.py    # refetch the Tabler icons, regenerate Icons.js
```

## License

MIT. `AirPodsIcon.qml` is from omapods (MIT, © 2026 GM). Tabler Icons are MIT.
Not affiliated with Apple, Glorious, HyperX or Razer.
