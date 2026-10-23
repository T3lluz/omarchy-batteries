# Run with: python3 -m unittest discover tests
import importlib.machinery
import importlib.util
import os
import unittest

_path = os.path.join(os.path.dirname(__file__), "..", "bin", "peripheral-battery")
_loader = importlib.machinery.SourceFileLoader("peripheral_battery", _path)
_spec = importlib.util.spec_from_loader("peripheral_battery", _loader)
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


if __name__ == "__main__":
    unittest.main()
