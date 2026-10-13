"""Reconcile the local MQTT entry and proxy settings through HA APIs."""
import asyncio
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import aiohttp
from onboarding import API


class ProvisionAPI(API):
    def ws(self, command, **fields):
        async def run():
            async with aiohttp.ClientSession() as session:
                async with session.ws_connect(self.base + '/api/websocket', timeout=15) as ws:
                    if (await ws.receive_json())['type'] != 'auth_required':
                        raise RuntimeError('Unexpected WebSocket handshake')
                    await ws.send_json({'type': 'auth', 'access_token': self.token})
                    if (await ws.receive_json())['type'] != 'auth_ok':
                        raise RuntimeError('WebSocket authentication failed')
                    await ws.send_json({'id': 1, 'type': command, **fields})
                    result = await ws.receive_json()
                    if not result.get('success'):
                        raise RuntimeError('HA API command failed: ' + command)
                    return result.get('result')
        return asyncio.run(run())

    def verify_proxy(self):
        # Exercise forwarded-header handling locally, without requiring DNS,
        # certificate issuance, or availability of any other host.
        request = urllib.request.Request(self.base + '/', headers={
            'X-Forwarded-For': '192.168.1.1', 'X-Forwarded-Proto': 'https',
        })
        with urllib.request.urlopen(request, timeout=15) as response:
            if response.status != 200:
                raise RuntimeError('Proxy header verification failed')


def login(api, username, password):
    client = api.base + '/'
    flow = api.request('/auth/login_flow', {
        'client_id': client, 'handler': ['homeassistant', None], 'redirect_uri': client,
    })
    result = api.request('/auth/login_flow/' + flow['flow_id'], {
        'client_id': client, 'username': username, 'password': password,
    })
    if result.get('type') != 'create_entry':
        raise RuntimeError('Owner login failed; refusing account changes')
    tokens = api.request('/auth/token', {
        'grant_type': 'authorization_code', 'code': result['result'], 'client_id': client,
    }, form=True)
    api.token = tokens['access_token']
    return tokens


def proxy_matches(config):
    return (config.get('use_x_forwarded_for') is True
            and config.get('trusted_proxies') == ['127.0.0.1/32'])


def reconcile_proxy(api, sleep=time.sleep):
    state = api.ws('http/config')
    if proxy_matches(state['stable']) and state['active_config_type'] == 'stable':
        api.verify_proxy()
        return
    pending = state.get('pending')
    if not (pending and not pending.get('error') and proxy_matches(pending)
            and state['active_config_type'] == 'pending'):
        desired = {key: value for key, value in state['stable'].items()
                   if key not in ('created_at', 'error', 'error_message')}
        desired.update(use_x_forwarded_for=True, trusted_proxies=['127.0.0.1/32'])
        api.ws('http/config/configure', config=desired)
        for _ in range(90):
            sleep(2)
            try:
                state = api.ws('http/config')
            except (aiohttp.ClientError, OSError, TimeoutError):
                continue
            if state['active_config_type'] == 'pending' and proxy_matches(state['pending']):
                break
            if state['active_config_type'] == 'stable' and proxy_matches(state['stable']):
                api.verify_proxy()
                return
        else:
            raise RuntimeError('Pending proxy configuration did not become active')
    api.verify_proxy()
    api.ws('http/config/promote')
    confirmed = api.ws('http/config')
    if not proxy_matches(confirmed['stable']):
        raise RuntimeError('Proxy configuration was not confirmed')


def reconcile_mqtt(api, password, sleep=time.sleep):
    entries = api.request('/api/config/config_entries/entry')
    mqtt = [entry for entry in entries if entry['domain'] == 'mqtt']
    if len(mqtt) > 1:
        raise RuntimeError('Multiple MQTT entries; refusing ambiguous ownership')
    if mqtt and mqtt[0]['title'] != '127.0.0.1':
        raise RuntimeError('Unmanaged MQTT entry; refusing replacement')
    data = {'handler': 'mqtt'}
    if mqtt:
        if mqtt[0].get('disabled_by'):
            raise RuntimeError('Managed MQTT entry is disabled; manual review required')
        data['entry_id'] = mqtt[0]['entry_id']
    flow = api.request('/api/config/config_entries/flow', data)
    if flow.get('type') != 'form' or flow.get('step_id') != 'broker':
        raise RuntimeError('Unexpected MQTT broker flow')
    result = api.request('/api/config/config_entries/flow/' + flow['flow_id'], {
        'broker': '127.0.0.1', 'port': 1883, 'username': 'home-assistant',
        'password': password, 'protocol': '3.1.1',
        'other_settings': {'set_ca_cert': 'off', 'set_client_cert': False, 'transport': 'tcp'},
    })
    if not (result.get('type') == 'create_entry' or
            (result.get('type') == 'abort' and result.get('reason') == 'reconfigure_successful')):
        raise RuntimeError('MQTT connection validation failed; existing entry preserved')
    for _ in range(30):
        current = [entry for entry in api.request('/api/config/config_entries/entry')
                   if entry['domain'] == 'mqtt']
        if len(current) == 1 and current[0]['state'] == 'loaded':
            if mqtt and current[0]['entry_id'] != mqtt[0]['entry_id']:
                raise RuntimeError('MQTT identity unexpectedly changed')
            print('Local MQTT configuration reconciled; entry loaded.')
            return
        sleep(2)
    raise RuntimeError('MQTT entry did not load')


def reconcile_users(api, users):
    existing = api.ws('config/auth/list')
    for username, config in users.items():
        password = config['password']
        if not password:
            raise RuntimeError('Empty managed user password')
        matches = [user for user in existing if user.get('username') == username]
        if len(matches) > 1:
            raise RuntimeError('Ambiguous managed account')
        if matches:
            user = matches[0]
            if user.get('is_owner') or user.get('system_generated'):
                raise RuntimeError('Refusing to adopt owner or system account')
            desired = {'name': config['name'], 'group_ids': ['system-users'], 'local_only': True}
            if any(user.get(key) != value for key, value in desired.items()):
                api.ws('config/auth/update', user_id=user['id'], **desired)
        else:
            # Never adopt an unrelated same-display-name account or duplicate a partial create.
            partial = [user for user in existing if user.get('name') == config['name']]
            if partial:
                if len(partial) != 1 or partial[0].get('username') is not None or partial[0].get('credentials'):
                    raise RuntimeError('Conflicting managed account identity')
                user = partial[0]
                if user.get('is_owner') or user.get('system_generated') or user.get('group_ids') != ['system-users']:
                    raise RuntimeError('Unsafe partial managed account')
            else:
                user = api.ws('config/auth/create', name=config['name'],
                              group_ids=['system-users'], local_only=True)['user']
            api.ws('config/auth_provider/homeassistant/create', user_id=user['id'],
                   username=username, password=password)
        # Existing credentials must match; don't silently reset passwords or invalidate tokens.
        remote = ProvisionAPI(api.base)
        tokens = login(remote, username, password)
        try:
            current = remote.ws('auth/current_user')
            if current.get('is_admin') or current.get('is_owner') or current['id'] != user['id']:
                raise RuntimeError('Managed account permission verification failed')
        finally:
            remote.request('/auth/token', {'action': 'revoke', 'token': tokens['refresh_token']}, form=True)
            remote.token = None
    if users:
        print('Managed local-only non-admin HA accounts verified; identities preserved.')


def provision(api, username, owner_password, mqtt_password, sleep=time.sleep, users=None):
    for attempt in range(90):
        try:
            api.request('/api/')
        except urllib.error.HTTPError as error:
            if error.code == 401:
                break
            if attempt == 89:
                raise
            sleep(2)
        except (urllib.error.URLError, TimeoutError):
            if attempt == 89:
                raise
            sleep(2)
        else:
            break
    tokens = login(api, username, owner_password)
    try:
        # Wait for HA to be fully running before any restart-capable HTTP change.
        for _ in range(90):
            if api.ws('get_config').get('state') == 'RUNNING':
                break
            sleep(2)
        else:
            raise RuntimeError('HA did not reach running state')
        reconcile_users(api, users or {})
        reconcile_proxy(api, sleep)
        reconcile_mqtt(api, mqtt_password, sleep)
        print('HA provisioning complete; account and device identities preserved.')
    finally:
        api.request('/auth/token', {
            'action': 'revoke', 'token': tokens['refresh_token'],
        }, form=True)
        api.token = None


def main():
    credentials = Path(os.environ['CREDENTIALS_DIRECTORY'])
    users = json.loads(os.environ.get('HA_MANAGED_USERS', '{}'))
    for user in users.values():
        user['password'] = (credentials / user.pop('credential')).read_text().strip()
    provision(ProvisionAPI('http://127.0.0.1:8123'), os.environ['HA_OWNER_USERNAME'],
              (credentials / 'owner-password').read_text().strip(),
              (credentials / 'mqtt-password').read_text().strip(), users=users)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # HTTP responses and config-flow forms can contain credentials.
        print('HA provisioning failed: ' + type(error).__name__, file=sys.stderr)
        sys.exit(1)
