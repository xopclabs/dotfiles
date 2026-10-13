"""COOLIX state packets for the observed ZG-IR01 Broadlink capture format.

Protocol fields/framing: IRremoteESP8266 src/ir_Coolix.{h,cpp}.
No networking or transmission: the CLI prints a Zigbee2MQTT payload only.
"""
import argparse
import base64
import json

OFF = 0xB27BE0
SWING = 0xB26BE0  # Swing toggle; vertical behavior needs physical verification.
VANE_STEP = 0xB20FE0  # One vertical step; must use a single wire frame.
LED = 0xB5F5A5  # Toggle, not an absolute light/sound setting.
TURBO = 0xB5F5A2  # Toggle; physically tested on this AC.
SILENCE_ON = 0xB5F5B6  # Captured from remote: user confirmed Silence OFF -> ON.
SILENCE_OFF = 0xB5F5B7  # Captured from remote: Silence ON -> OFF.
# Generated Silence ON/OFF replay is not yet physically verified.
TEMPERATURES = (0, 1, 3, 2, 6, 7, 5, 4, 12, 13, 9, 8, 10, 11)
MODES = {'cool': 0, 'dry': 1, 'auto': 2, 'heat': 3, 'fan': 1}
FANS = {'1': 4, '2': 2, '3': 1, 'auto': 5}


def state_code(mode='cool', temperature=24, fan='auto'):
    if mode not in MODES or fan not in FANS:
        raise ValueError('Unsupported mode or fan speed')
    if isinstance(temperature, bool) or not isinstance(temperature, int) or not 17 <= temperature <= 30:
        raise ValueError('Temperature must be an integer from 17 to 30 Celsius')
    # Auto/dry use their dedicated auto-fan encoding. Do not pretend manual
    # fan settings in these modes are supported by the physical appliance.
    if mode in ('auto', 'dry') and fan != 'auto':
        raise ValueError('Auto and dry require auto fan')
    fan_bits = 0 if mode in ('auto', 'dry') else FANS[fan]
    temp_bits = 14 if mode == 'fan' else TEMPERATURES[temperature - 17]
    return 0xB20000 | (fan_bits << 13) | (31 << 8) | (temp_bits << 4) | (MODES[mode] << 2)


def wire_bytes(code):
    if not isinstance(code, int) or not 0 <= code <= 0xFFFFFF:
        raise ValueError('Expected a 24-bit code')
    return bytes(byte for value in code.to_bytes(3, 'big') for byte in (value, value ^ 255))


def packet(code):
    # Observed pulse quantization: ticks of 269/8192 milliseconds.
    # Both real captures contain two frames, one intervening gap, and no
    # trailing gap/terminator. Their length field includes the four-byte header.
    # Preserve this firmware-specific format instead of guessing Tuya encoding.
    frame = bytearray((138, 136))
    for value in wire_bytes(code):
        for shift in range(7, -1, -1):
            frame.extend((17, 49 if value & (1 << shift) else 15))
    frame.append(17)
    # IRremoteESP8266 explicitly disables repetition for vertical vane steps.
    body = frame if code == VANE_STEP else frame + bytes((161,)) + frame
    raw = bytes((0x26, 0)) + (len(body) + 4).to_bytes(2, 'little') + body
    return base64.b64encode(raw).decode('ascii')


def decode_packet(encoded):
    raw = base64.b64decode(encoded, validate=True)
    if len(raw) < 4 or raw[:2] != bytes((0x26, 0)):
        raise ValueError('Not an observed Broadlink IR capture')
    if int.from_bytes(raw[2:4], 'little') != len(raw):
        raise ValueError('Unexpected firmware packet length')
    pulses = []
    offset = 4
    while offset < len(raw):
        pulse = raw[offset]
        offset += 1
        if pulse == 0:
            if offset + 2 > len(raw):
                raise ValueError('Truncated extended pulse')
            pulse = int.from_bytes(raw[offset:offset + 2], 'big')
            offset += 2
        pulses.append(pulse)
    codes = []
    for start in range(len(pulses) - 98):
        if not (120 <= pulses[start] <= 155 and 120 <= pulses[start + 1] <= 155):
            continue
        bits = []
        for bit in range(48):
            mark, space = pulses[start + 2 + 2 * bit:start + 4 + 2 * bit]
            if not 12 <= mark <= 23 or not (10 <= space <= 23 or 40 <= space <= 58):
                raise ValueError('Invalid COOLIX bit timings')
            bits.append(int(space >= 40))
        value = int(''.join(map(str, bits)), 2)
        wire = value.to_bytes(6, 'big')
        if any(wire[i] ^ wire[i + 1] != 255 for i in (0, 2, 4)):
            raise ValueError('Invalid inverted-byte checks')
        codes.append(int.from_bytes(wire[::2], 'big'))
    if not codes:
        raise ValueError('No COOLIX frames')
    expected_frames = 1 if codes[0] == VANE_STEP else 2
    if len(codes) != expected_frames or any(code != codes[0] for code in codes):
        raise ValueError('Unexpected COOLIX frame count or mismatched repeats')
    return codes[0]


def mqtt_payload(code):
    return {'ir_code_to_send': packet(code)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('on', 'off', 'led', 'turbo', 'silence-on', 'silence-off', 'swing', 'vane-step'))
    parser.add_argument('--mode', choices=MODES, default='cool')
    parser.add_argument('--temperature', type=int, default=24)
    parser.add_argument('--fan', choices=FANS, default='auto')
    args = parser.parse_args()
    try:
        code = {'off': OFF, 'led': LED, 'turbo': TURBO,
                'silence-on': SILENCE_ON, 'silence-off': SILENCE_OFF,
                'swing': SWING, 'vane-step': VANE_STEP}.get(args.command)
        if code is None:
            code = state_code(args.mode, args.temperature, args.fan)
        print(json.dumps(mqtt_payload(code)))
    except ValueError as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()
