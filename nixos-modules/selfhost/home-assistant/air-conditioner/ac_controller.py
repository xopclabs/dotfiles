"""Persistent, serialized COOLIX control with Home Assistant MQTT discovery."""
import argparse
from dataclasses import asdict, dataclass
import json
import logging
import math
import os
from pathlib import Path
import queue
import signal
import threading
import time

from coolix import OFF, LED, TURBO, SWING, VANE_STEP, SILENCE_ON, SILENCE_OFF, state_code, mqtt_payload

BASE = 'homeassistant/bodner_ac'
TOTAL_STEPS = 12


@dataclass
class State:
    power: bool | None = None
    mode: str = 'fan_only'
    temperature: int = 24
    fan: str = 'auto'
    silent: bool | None = False
    silence: bool | None = None
    turbo: bool | None = False
    swing: bool | None = None
    position: int | None = None
    direction: int | None = None
    last_action: str = 'Ready; state is estimated, not AC feedback'

    def validate(self):
        state_code('fan' if self.mode == 'fan_only' else self.mode, self.temperature, self.fan)
        for field in ('power', 'silent', 'silence', 'turbo', 'swing'):
            if getattr(self, field) is not None and type(getattr(self, field)) is not bool:
                raise ValueError('Invalid persisted boolean')
        if (self.position is None) != (self.direction is None):
            raise ValueError('Incomplete vane calibration')
        if self.position is not None:
            if type(self.position) is not int or not 0 <= self.position <= TOTAL_STEPS or type(self.direction) is not int or self.direction not in (-1, 1):
                raise ValueError('Invalid vane calibration')


def next_step(position, direction):
    if position == 0 and direction == -1:
        direction = 1
    elif position == TOTAL_STEPS and direction == 1:
        direction = -1
    return position + direction, direction


def plan_steps(position, direction, target):
    if type(target) is not int or not 0 <= target <= TOTAL_STEPS:
        raise ValueError('Vane position must be an integer from 0 to 12')
    result = []
    for _ in range(2 * TOTAL_STEPS + 1):
        if position == target:
            return result
        position, direction = next_step(position, direction)
        result.append((position, direction))
    raise ValueError('Cannot reach vane target')


class Controller:
    def __init__(self, state, send, changed, sleep=time.sleep, cancel=None):
        self.state = state
        self.send = send
        self.changed = changed
        self.sleep = sleep
        self.cancel = cancel or threading.Event()

    def commit(self, message):
        self.state.last_action = message
        self.changed(self.state)

    def invalidate_vane(self):
        self.state.position = self.state.direction = None

    def adjust(self, target=None):
        state = self.state
        if state.swing is not False:
            raise ValueError('Stop swing and sync Swing OFF before using DIRECT')
        if state.silent is None:
            raise ValueError('Sync indication state before using DIRECT; state is unknown')
        if target is not None and state.position is None:
            raise ValueError('Sync vane after its first reversed movement')
        path = [(None, None)] if target is None and state.position is None else (
            [next_step(state.position, state.direction)] if target is None else
            plan_steps(state.position, state.direction, target))
        if not path:
            return
        previous_silent = state.silent
        self.cancel.clear()
        try:
            if not previous_silent:
                try:
                    self.send(LED)
                except Exception:
                    state.silent = None
                    raise
                state.silent = True
                self.commit('Indication temporarily disabled')
            for index, (position, direction) in enumerate(path):
                if self.cancel.is_set():
                    break
                try:
                    self.send(VANE_STEP)
                except Exception:
                    self.invalidate_vane()
                    raise
                state.position, state.direction = position, direction
                self.commit(f'DIRECT {index + 1}/{len(path)}; estimated position {position}')
                if index + 1 < len(path):
                    self.sleep(1)
        finally:
            if not previous_silent and state.silent is True:
                try:
                    self.send(LED)
                    state.silent = False
                except Exception:
                    state.silent = None
                    raise
                finally:
                    self.changed(state)
        self.commit('Vane adjustment cancelled' if self.cancel.is_set() else 'Vane adjustment complete (estimated)')

    def execute(self, command, value=''):
        state = self.state
        if command == 'power':
            if value not in ('ON', 'OFF'):
                raise ValueError('Expected ON or OFF')
            command = 'power_on' if value == 'ON' else 'power_off'
        if command.startswith('sync_'):
            if command == 'sync_top_down':
                state.position, state.direction, state.swing = 1, 1, False
            elif command == 'sync_bottom_up':
                state.position, state.direction, state.swing = TOTAL_STEPS - 1, -1, False
            else:
                field, status = command[5:].rsplit('_', 1)
                if field not in ('silent', 'swing', 'turbo') or status not in ('on', 'off'):
                    raise ValueError('Unknown sync action')
                setattr(state, field, status == 'on')
                if field == 'swing' and status == 'on':
                    self.invalidate_vane()
            self.commit('Synced estimate only; no IR sent: ' + command)
            return
        if command == 'invalidate':
            self.invalidate_vane()
            state.silent = state.swing = state.turbo = state.silence = None
            state.power = None
            self.commit('Remote used / state uncertain; estimates invalidated')
            return
        if command == 'direct':
            self.adjust()
            return
        if command == 'position':
            number = float(value)
            if not math.isfinite(number) or not number.is_integer():
                raise ValueError('Vane position must be an integer')
            self.adjust(int(number))
            return
        if command in ('silent', 'turbo', 'swing'):
            if value not in ('ON', 'OFF'):
                raise ValueError('Expected ON or OFF')
            previous = getattr(state, command)
            if previous is None:
                raise ValueError('Sync this toggle state before using its switch')
            desired = value == 'ON'
            if previous != desired:
                try:
                    self.send({'silent': LED, 'turbo': TURBO, 'swing': SWING}[command])
                except Exception:
                    setattr(state, command, None)
                    if command == 'swing':
                        self.invalidate_vane()
                    raise
                setattr(state, command, desired)
                if command == 'swing':
                    self.invalidate_vane()
        elif command in ('silence', 'silence_on', 'silence_off'):
            desired = command == 'silence_on' if command != 'silence' else value == 'ON'
            if command == 'silence' and value not in ('ON', 'OFF'):
                raise ValueError('Expected ON or OFF')
            self.send(SILENCE_ON if desired else SILENCE_OFF)
            state.silence = desired
        elif command in ('power_on', 'power_off', 'mode', 'temperature', 'fan', 'temp_up', 'temp_down'):
            candidate = State(**asdict(state))
            if command == 'mode' and value != 'off':
                if value not in ('auto', 'cool', 'heat', 'dry', 'fan_only'):
                    raise ValueError('Unknown mode')
                candidate.mode = value
                if value in ('auto', 'dry'):
                    candidate.fan = 'auto'
            elif command == 'fan':
                candidate.fan = value
            elif command in ('temperature', 'temp_up', 'temp_down'):
                if state.mode in ('dry', 'fan_only'):
                    raise ValueError('Temperature adjustment is unavailable in dry and fan modes')
                number = float(value) if command == 'temperature' else state.temperature + (1 if command == 'temp_up' else -1)
                if not math.isfinite(number) or not float(number).is_integer():
                    raise ValueError('Temperature must be an integer')
                candidate.temperature = max(17, min(30, int(number))) if command != 'temperature' else int(number)
            candidate.validate()
            if command == 'power_off' or (command == 'mode' and value == 'off'):
                self.send(OFF)
                state.power = False
                self.invalidate_vane()
            else:
                turn_on = command in ('mode', 'power_on')
                transmit = turn_on or state.power is True
                if transmit:
                    self.send(state_code('fan' if candidate.mode == 'fan_only' else candidate.mode,
                                         candidate.temperature, candidate.fan))
                    if candidate.mode != state.mode or state.power is not True:
                        self.invalidate_vane()
                    state.power = True
                state.mode, state.temperature, state.fan = candidate.mode, candidate.temperature, candidate.fan
        else:
            raise ValueError('Unknown command')
        self.commit(command + ' requested; state is estimated')


BUTTONS = {
    'power_on': 'Power on', 'power_off': 'Power off',
    'temp_up': 'Temperature +', 'temp_down': 'Temperature −',
    'direct': 'Step', 'cancel': 'Cancel vane adjustment',
    'sync_top_down': 'Sync: just moved down from top',
    'sync_bottom_up': 'Sync: just moved up from bottom',
    'invalidate': 'Remote used: invalidate estimates',
    'silence_on': 'Low noise on', 'silence_off': 'Low noise off',
    'sync_silent_on': 'Sync Indication off',
    'sync_silent_off': 'Sync Indication on',
    'sync_swing_on': 'Sync swing on', 'sync_swing_off': 'Sync swing off',
    'sync_turbo_on': 'Sync Turbo on', 'sync_turbo_off': 'Sync Turbo off',
}


def discovery(device_id, mode=None):
    device = {'identifiers': ['bodner_ac'], 'name': 'AC', 'manufacturer': 'Bodner',
              'model': 'COOLIX via ZG-IR01'}
    items = {}
    def add(component, key, name, extra=None, known=None):
        availability = [{'topic': BASE + '/availability'},
                        {'topic': 'zigbee2mqtt/bridge/state', 'value_template': '{{ value_json.state }}'}]
        if known:
            availability.append({'topic': BASE + '/available/' + known})
        config = {'name': name, 'unique_id': 'bodner_ac_' + key, 'device': device,
                  'default_entity_id': component + '.bodner_ac' + ('' if key == 'climate' else '_' + key),
                  'availability': availability, 'availability_mode': 'all',
                  'json_attributes_topic': BASE + '/attributes'}
        config.update(extra or {})
        items[f'homeassistant/{component}/bodner_ac/{key}/config'] = config
    add('switch', 'power', 'Power', {'command_topic': BASE + '/command/power',
                                  'state_topic': BASE + '/state/power', 'icon': 'mdi:power'})
    add('climate', 'climate', None, {
        'modes': ['off', 'auto', 'cool', 'heat', 'dry', 'fan_only'],
        'mode_command_topic': BASE + '/command/mode', 'mode_state_topic': BASE + '/state/mode',
        **({'temperature_command_topic': BASE + '/command/temperature'}
           if mode not in ('dry', 'fan_only') else {}),
        'temperature_state_topic': BASE + '/state/temperature',
        'fan_mode_command_topic': BASE + '/command/fan', 'fan_mode_state_topic': BASE + '/state/fan',
        'fan_mode_command_template': "{{ {'low': '1', 'medium': '2', 'high': '3'}.get(value, value) }}",
        'fan_mode_state_template': "{{ {'1': 'low', '2': 'medium', '3': 'high'}.get(value, value) }}",
        'fan_modes': ['auto'] if mode in ('auto', 'dry') else ['low', 'medium', 'high', 'auto'],
        'min_temp': 17, 'max_temp': 30, 'temp_step': 1,
        'temperature_unit': 'C', 'current_temperature_topic': 'zigbee2mqtt/' + device_id,
        'current_temperature_template': '{{ value_json.temperature }}',
    })
    for key, name in [('silent', 'Indication'), ('silence', 'Low noise'),
                      ('turbo', 'Turbo'), ('swing', 'Swing')]:
        extra = {'command_topic': BASE + '/command/' + key, 'state_topic': BASE + '/state/' + key}
        if key == 'silent':
            # Keep suppression tracking for vane adjustments; invert only the HA switch.
            extra.update(payload_on='OFF', payload_off='ON')
        add('switch', key, name, extra, known=None if key == 'silence' else key)
    add('number', 'position', 'Vane', {
        'command_topic': BASE + '/command/position', 'state_topic': BASE + '/state/position',
        'min': 0, 'max': 12, 'step': 1, 'mode': 'slider', 'icon': 'mdi:air-filter',
    }, known='position')
    add('sensor', 'last_action', 'Status', {'state_topic': BASE + '/state/last_action',
                                         'entity_category': 'diagnostic'})
    for key, name in BUTTONS.items():
        extra = {'command_topic': BASE + '/command/' + key, 'payload_press': 'PRESS'}
        if key.startswith('sync_') or key == 'invalidate':
            extra['entity_category'] = 'config'
        add('button', key, name, extra, known='direct' if key == 'direct' else None)
    return items


def main():
    import paho.mqtt.client as mqtt
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--password-file', required=True)
    parser.add_argument('--state-file', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    logging.basicConfig(level=logging.INFO, format='%(levelname)s %(message)s')
    path = Path(args.state_file)
    state = State(**json.loads(path.read_text())) if path.exists() else State()
    state.validate()
    tasks = queue.Queue(maxsize=64)
    connected = threading.Event()
    zigbee_ready = threading.Event()
    cancel = threading.Event()
    stopping = threading.Event()

    def stop(signum, frame):
        # Finish the current publication, stop movement, and restore SILENT
        # before disconnecting. A service restart must not kill that finally block.
        stopping.set()
        cancel.set()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id='bodner-ac-controller')
    client.username_pw_set('home-assistant', Path(args.password_file).read_text().strip())
    client.will_set(BASE + '/availability', 'offline', qos=1, retain=True)

    def publish(topic, payload, retain=True):
        if not connected.is_set():
            raise RuntimeError('MQTT disconnected; refusing to queue IR for later')
        info = client.publish(topic, payload, qos=0, retain=retain)
        info.wait_for_publish(timeout=5)
        if not info.is_published():
            raise RuntimeError('MQTT publication not completed')

    def send(code):
        if not zigbee_ready.is_set():
            raise RuntimeError('Zigbee2MQTT offline; refusing IR command')
        publish('zigbee2mqtt/' + args.device + '/set', json.dumps(mqtt_payload(code)), retain=False)

    announced_climate_config = None

    def changed(current):
        nonlocal announced_climate_config
        configs = discovery(args.device, current.mode)
        climate_topic = 'homeassistant/climate/bodner_ac/climate/config'
        climate_config = configs[climate_topic]
        if climate_config != announced_climate_config:
            publish(climate_topic, json.dumps(climate_config))
            announced_climate_config = climate_config
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(asdict(current), indent=2))
        temporary.replace(path)
        attributes = {**asdict(current), 'state_source': 'commanded / estimated; no AC feedback',
                      'temperature_source': 'ZG-IR01 sensor; not SCD41', 'vane_travel_steps': TOTAL_STEPS}
        publish(BASE + '/attributes', json.dumps(attributes))
        known = {key: getattr(current, key) is not None for key in ('silent', 'silence', 'turbo', 'swing')}
        known['direct'] = current.swing is False and current.silent is not None
        known['position'] = current.position is not None and known['direct']
        for key, available in known.items():
            publish(BASE + '/available/' + key, 'online' if available else 'offline')
        publish(BASE + '/state/power', 'None' if current.power is None else 'ON' if current.power else 'OFF')
        publish(BASE + '/state/mode', 'None' if current.power is None else current.mode if current.power else 'off')
        publish(BASE + '/state/temperature', str(current.temperature))
        publish(BASE + '/state/fan', current.fan)
        for key in ('silent', 'silence', 'turbo', 'swing'):
            value = getattr(current, key)
            publish(BASE + '/state/' + key, 'None' if value is None else 'ON' if value else 'OFF')
        if current.position is not None:
            publish(BASE + '/state/position', str(current.position))
        publish(BASE + '/state/last_action', current.last_action[:250])

    controller = Controller(state, send, changed, cancel=cancel)

    def on_connect(client, userdata, flags, reason_code, properties):
        if reason_code.is_failure:
            logging.error('MQTT authentication/connection failed')
            return
        connected.set()
        client.subscribe(BASE + '/command/+', qos=0)
        client.subscribe('homeassistant/status', qos=0)
        client.subscribe('zigbee2mqtt/bridge/state', qos=0)
        try:
            tasks.put_nowait(('announce', ''))
        except queue.Full:
            logging.warning('Announcement delayed: command queue full')

    def on_disconnect(client, userdata, flags, reason_code, properties):
        connected.clear()
        zigbee_ready.clear()
        cancel.set()

    def on_message(client, userdata, message):
        try:
            value = message.payload.decode('utf-8')
            if message.topic == 'zigbee2mqtt/bridge/state':
                if json.loads(value).get('state') == 'online':
                    zigbee_ready.set()
                else:
                    zigbee_ready.clear()
                    cancel.set()
                return
            if message.topic == 'homeassistant/status':
                if value == 'online':
                    tasks.put_nowait(('announce', ''))
                return
            if message.retain:
                logging.warning('Ignored retained command (never replay commands on restart)')
                return
            command = message.topic.rsplit('/', 1)[1]
            if command == 'cancel':
                cancel.set()
            else:
                tasks.put_nowait((command, value))
        except (UnicodeError, ValueError, AttributeError, queue.Full):
            logging.warning('Ignored invalid command or full command queue')

    client.on_connect, client.on_disconnect, client.on_message = on_connect, on_disconnect, on_message
    client.connect('127.0.0.1', 1883, keepalive=30)
    client.loop_start()
    try:
        while not stopping.is_set():
            try:
                command, value = tasks.get(timeout=1)
            except queue.Empty:
                continue
            if stopping.is_set():
                break
            try:
                if command == 'announce':
                    configs = discovery(args.device, state.mode)
                    for topic, config in configs.items():
                        publish(topic, json.dumps(config))
                    announced_climate_config = configs['homeassistant/climate/bodner_ac/climate/config']
                    changed(state)
                    publish(BASE + '/availability', 'online')
                else:
                    controller.execute(command, value)
            except Exception as error:
                logging.warning('Command failed: %s', type(error).__name__)
                state.last_action = str(error)[:250] if isinstance(error, ValueError) else 'Transport error; command outcome uncertain'
                if not isinstance(error, ValueError):
                    state.power = state.silent = state.swing = state.turbo = state.silence = None
                    controller.invalidate_vane()
                try:
                    changed(state)
                except Exception:
                    logging.warning('Could not persist/publish current estimate')
    finally:
        if connected.is_set():
            publish(BASE + '/availability', 'offline')
        client.disconnect()
        client.loop_stop()


if __name__ == '__main__':
    main()
