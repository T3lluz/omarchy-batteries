# Run with: python3 -m unittest discover tests
import sys

# Importing bin/batteries would leave bytecode in bin/__pycache__, inside the
# plugin folder, and the shell reloads every plugin when a file appears there.
sys.dont_write_bytecode = True

import importlib.machinery
import importlib.util
import json
import os
import tempfile
import unittest

_path = os.path.join(os.path.dirname(__file__), "..", "bin", "batteries")
_loader = importlib.machinery.SourceFileLoader("batteries", _path)
_spec = importlib.util.spec_from_loader("batteries", _loader)
pb = importlib.util.module_from_spec(_spec)
_loader.exec_module(pb)


def mow_reply(marker, level):
    buf = bytearray(65)
    buf[1] = marker
    buf[3] = 0x02
    buf[4] = 0x02
    buf[6] = 0x83
    buf[8] = level
    return bytes(buf)


UPOWER_DUMP = """Device: /org/freedesktop/UPower/devices/line_power_ADP0
  native-path:          ADP0
  power supply:         yes
  line-power
    online:              yes

Device: /org/freedesktop/UPower/devices/battery_BAT0
  native-path:          BAT0
  power supply:         yes
  battery
    present:             yes
    state:               charging
    percentage:          88%

Device: /org/freedesktop/UPower/devices/mouse_hidpp_battery_0
  native-path:          hidpp_battery_0
  model:                G502 LIGHTSPEED Wireless Gaming Mouse
  power supply:         no
  updated:              Thu 23 Oct 2026 12:00:00 (5 seconds ago)
  has history:          yes
  mouse
    present:             yes
    rechargeable:        yes
    state:               discharging
    warning-level:       none
    battery-level:       normal
    percentage:          55% (should be ignored)
    icon-name:          'battery-good-symbolic'

Device: /org/freedesktop/UPower/devices/headset_dev_AA_BB
  native-path:          /org/bluez/hci0/dev_AA_BB
  model:                WH-1000XM5
  power supply:         no
  headset
    present:             yes
    state:               pending-charge
    percentage:          40%

Device: /org/freedesktop/UPower/devices/DisplayDevice
  power supply:         yes
  battery
    percentage:          88%

Daemon:
  daemon-version:  1.90.4
"""


class MowTest(unittest.TestCase):
    def test_active(self):
        self.assertEqual(pb.parse_mow(mow_reply(0xA1, 77)), {"state": "active", "level": 77})

    def test_zero_reads_as_one(self):
        self.assertEqual(pb.parse_mow(mow_reply(0xA1, 0))["level"], 1)

    def test_asleep_has_no_level(self):
        self.assertEqual(pb.parse_mow(mow_reply(0xA4, 0)), {"state": "asleep", "level": None})

    def test_waking(self):
        self.assertEqual(pb.parse_mow(mow_reply(0xA3, 50))["state"], "waking")

    def test_not_a_battery_reply(self):
        bad = bytearray(mow_reply(0xA1, 50))
        bad[6] = 0
        self.assertIsNone(pb.parse_mow(bytes(bad)))
        self.assertIsNone(pb.parse_mow(None))
        self.assertIsNone(pb.parse_mow(mow_reply(0xA1, 200)))

    def test_request(self):
        req = pb.mow_request()
        self.assertEqual(len(req), 65)
        self.assertEqual((req[3], req[4], req[6]), (0x02, 0x02, 0x83))


class GloriousSelectionTest(unittest.TestCase):
    """Cable vs 2.4 GHz, with the HID exchange stubbed out."""

    def setUp(self):
        self.replies = {}
        self._orig = pb.feature_exchange
        pb.feature_exchange = lambda dev, *a, **k: self.replies.get(dev)

    def tearDown(self):
        pb.feature_exchange = self._orig

    def nodes(self, cable=True, dongle=True):
        out = []
        if cable:
            out += [{"dev": "/dev/c%d" % i, "vid": 0x258A, "pid": 0x2011, "iface": i, "name": "", "bus": 3} for i in range(3)]
        if dongle:
            out += [{"dev": "/dev/d%d" % i, "vid": 0x258A, "pid": 0x2022, "iface": i, "name": "", "bus": 3} for i in range(3)]
        return out

    def test_cable_is_charging(self):
        self.replies = {"/dev/c2": mow_reply(0xA1, 77), "/dev/d2": mow_reply(0xA4, 0)}
        [dev] = pb.glorious_wireless(self.nodes(), [])
        self.assertEqual((dev["level"], dev["charging"], dev["status"], dev["connection"]), (77, True, "charging", "usb"))

    def test_cable_full(self):
        self.replies = {"/dev/c2": mow_reply(0xA1, 100)}
        [dev] = pb.glorious_wireless(self.nodes(dongle=False), [])
        self.assertEqual((dev["charging"], dev["status"]), (False, "full"))

    def test_dongle_on_battery(self):
        self.replies = {"/dev/d2": mow_reply(0xA1, 64)}
        [dev] = pb.glorious_wireless(self.nodes(cable=False), [])
        self.assertEqual((dev["level"], dev["charging"], dev["status"], dev["connection"]), (64, False, "discharging", "wireless"))

    def test_dongle_asleep(self):
        self.replies = {"/dev/d2": mow_reply(0xA4, 0)}
        [dev] = pb.glorious_wireless(self.nodes(cable=False), [])
        self.assertEqual((dev["level"], dev["status"]), (None, "asleep"))

    def test_dongle_mouse_off(self):
        [dev] = pb.glorious_wireless(self.nodes(cable=False), [])
        self.assertEqual(dev["status"], "offline")

    def test_nothing_plugged(self):
        self.assertEqual(pb.glorious_wireless([], []), [])

    def test_no_access(self):
        def deny(dev, *a, **k):
            raise pb.NoAccess(dev)
        pb.feature_exchange = deny
        denied = []
        [dev] = pb.glorious_wireless(self.nodes(), denied)
        self.assertEqual(dev["status"], "no-access")
        self.assertEqual(denied, ["/dev/c2"])


class UPowerTest(unittest.TestCase):
    def test_dump(self):
        devs = pb.parse_upower_dump(UPOWER_DUMP)
        self.assertEqual([d["name"] for d in devs], ["G502 LIGHTSPEED Wireless Gaming Mouse", "WH-1000XM5"])
        mouse, headset = devs
        self.assertEqual((mouse["kind"], mouse["level"], mouse["status"], mouse["connection"]), ("mouse", 55, "discharging", "wireless"))
        self.assertEqual((headset["kind"], headset["level"], headset["charging"], headset["connection"]), ("headset", 40, True, "bluetooth"))


class OtherParsersTest(unittest.TestCase):
    def test_hyperx(self):
        data = bytes([0x21, 0xBB, 0x0B, 63]) + bytes(27) + bytes([0x21, 0xBB, 0x0C, 0x01]) + bytes(27)
        self.assertEqual(pb.parse_hyperx(data), (63, True))
        self.assertEqual(pb.parse_hyperx(b""), (None, None))

    def test_sinowealth(self):
        self.assertEqual(pb.parse_sinowealth(bytes([5, 0x1D, 80, 1, 0, 0, 0, 0])), {"level": 80, "charging": True})
        self.assertIsNone(pb.parse_sinowealth(bytes([5, 0x1C, 80, 1, 0, 0])))

    def test_headsetcontrol(self):
        text = '{"devices":[{"status":"success","product":"Arctis 7","id_vendor":"0x1038","id_product":"0x12ad","battery":{"status":"BATTERY_AVAILABLE","level":70}},{"status":"success","product":"Wired","battery":{"status":"BATTERY_UNAVAILABLE","level":-1}}]}'
        [dev] = pb.parse_headsetcontrol(text)
        self.assertEqual((dev["name"], dev["level"], dev["charging"]), ("Arctis 7", 70, False))
        self.assertEqual(pb.parse_headsetcontrol("nope"), [])

    def test_merge_first_source_wins(self):
        a = {"name": "HyperX Cloud Alpha Wireless", "source": "hyperx"}
        b = {"name": "HyperX Cloud Alpha  wireless", "source": "headsetcontrol"}
        self.assertEqual(pb.merge([[a], [b]]), [a])


def write_supply(root, name, **files):
    d = os.path.join(root, name)
    os.makedirs(d)
    for k, v in files.items():
        with open(os.path.join(d, k), "w") as f:
            f.write(str(v) + "\n")


class LaptopTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()

    def bat(self, **over):
        files = dict(type="Battery", status="Discharging", energy_now=30000000, energy_full=60000000,
                     energy_full_design=80000000, power_now=15000000, voltage_now=16000000, cycle_count=42)
        files.update(over)
        write_supply(self.root, "BAT0", **files)

    def test_discharging(self):
        self.bat()
        write_supply(self.root, "ADP0", type="Mains", online=0)
        lap = pb.laptop({}, self.root)
        self.assertEqual((lap["level"], lap["status"], lap["rateW"], lap["timeToEmpty"]), (50, "discharging", 15.0, 7200))
        self.assertEqual((lap["health"], lap["cycles"], lap["acOnline"]), (75, 42, False))

    def test_upower_time_wins(self):
        self.bat()
        lap = pb.laptop({"BAT0": {"timeToEmpty": 6000}}, self.root)
        self.assertEqual(lap["timeToEmpty"], 6000)

    def test_charging_to_limit(self):
        self.bat(status="Charging", charge_control_end_threshold=80)
        write_supply(self.root, "ADP0", type="Mains", online=1)
        lap = pb.laptop({}, self.root)
        # 30 Wh now, 48 Wh at the 80% limit, at 15 W: 72 minutes.
        self.assertEqual((lap["status"], lap["charging"], lap["timeToFull"], lap["chargeLimit"]), ("charging", True, 4320, 80))

    def test_held_at_limit(self):
        self.bat(status="Not charging", energy_now=54000000, power_now=0, charge_control_end_threshold=90)
        write_supply(self.root, "ADP0", type="Mains", online=1)
        lap = pb.laptop({}, self.root)
        self.assertEqual((lap["level"], lap["status"], lap["rateW"]), (90, "held", 0.0))

    def test_charge_units(self):
        write_supply(self.root, "BAT0", type="Battery", status="Discharging", charge_now=2000000,
                     charge_full=4000000, charge_full_design=5000000, current_now=1000000, voltage_now=12000000)
        lap = pb.laptop({}, self.root)
        self.assertEqual((lap["level"], lap["rateW"], lap["health"]), (50, 12.0, 80))

    def test_device_scope_is_not_the_laptop(self):
        write_supply(self.root, "hidpp_battery_0", type="Battery", scope="Device", capacity=50)
        self.assertIsNone(pb.laptop({}, self.root))

    def test_upower_times(self):
        dump = "Device: /org/freedesktop/UPower/devices/battery_BAT0\n  native-path:          BAT0\n  power supply:         yes\n  battery\n    time to empty:       3.5 hours\n"
        self.assertEqual(pb.parse_upower_battery_times(dump), {"BAT0": {"timeToEmpty": 12600}})


class AirPodsTest(unittest.TestCase):
    def status(self, **over):
        s = {"schema_version": 1, "connected": True, "device_name": "AirPods Pro", "model_name": "AirPods Pro 2 (USB-C)",
             "is_pro_series": True, "is_headset": False,
             "left": {"available": True, "level": 80, "charging": False, "in_ear": True},
             "right": {"available": True, "level": 65, "charging": False, "in_ear": False},
             "case": {"available": True, "level": 40, "charging": True},
             "headset": {"available": False, "level": 0, "charging": False}}
        s.update(over)
        return json.dumps(s)

    def test_buds_and_case(self):
        p = pb.parse_librepods(self.status())
        self.assertEqual((p["level"], p["charging"], p["known"], p["connected"]), (65, False, True, True))
        self.assertEqual(p["left"], {"level": 80, "charging": False, "inEar": True})
        self.assertEqual(p["case"], {"level": 40, "charging": True})

    def test_unavailable_parts_are_none(self):
        off = {"available": False, "level": 0, "charging": False, "in_ear": False}
        p = pb.parse_librepods(self.status(connected=False, left=off, right=off, case=off))
        self.assertEqual((p["level"], p["known"], p["left"]), (None, False, None))

    def test_max(self):
        p = pb.parse_librepods(self.status(is_headset=True, headset={"available": True, "level": 55, "charging": True}))
        self.assertEqual((p["level"], p["charging"], p["isHeadset"]), (55, True, True))

    def test_not_librepods(self):
        self.assertIsNone(pb.parse_librepods("{}"))
        self.assertIsNone(pb.parse_librepods(""))

    def test_airpods_win_over_bluez(self):
        bluez = {"name": "AirPods Pro", "source": "upower"}
        self.assertEqual(pb.merge([[bluez]], ("AirPods Pro",)), [])


class PhoneTest(unittest.TestCase):
    def test_kdeconnect(self):
        self.assertEqual(pb.parse_kdeconnect_battery("({'charge': <85>, 'isCharging': <true>},)"), (85, True))
        self.assertEqual(pb.parse_kdeconnect_battery("({'charge': <-1>},)"), (None, False))

    def test_ideviceinfo(self):
        self.assertEqual(pb.parse_ideviceinfo("BatteryCurrentCapacity: 77\nBatteryIsCharging: true\n"),
                         {"BatteryCurrentCapacity": "77", "BatteryIsCharging": "true"})


if __name__ == "__main__":
    unittest.main()
