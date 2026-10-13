"""One-time HA onboarding through the pinned HA HTTP API; never edit .storage."""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


class API:
    def __init__(self, base):
        self.base = base
        self.token = None

    def request(self, path, data=None, form=False):
        headers = {}
        if self.token:
            headers['Authorization'] = 'Bearer ' + self.token
        payload = None
        if data is not None:
            headers['Content-Type'] = ('application/x-www-form-urlencoded' if form
                                       else 'application/json')
            payload = (urllib.parse.urlencode(data) if form else json.dumps(data)).encode()
        request = urllib.request.Request(self.base + path, payload, headers)
        with urllib.request.urlopen(request, timeout=15) as response:
            body = response.read()
            return json.loads(body) if body else {}

    def status(self):
        # HA stops exposing onboarding once it has finished (after restart).
        try:
            return self.request('/api/onboarding')
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return []
            raise


def onboard(api, owner, password, sleep=time.sleep):
    for attempt in range(90):
        try:
            status = api.status()
            break
        except (urllib.error.URLError, TimeoutError):
            if attempt == 89:
                raise RuntimeError('HA did not become ready') from None
            sleep(2)
    pending = {step['step'] for step in status if not step['done']}
    if not pending:
        print('HA onboarding already complete; accounts unchanged.')
        return
    if pending - {'user', 'core_config', 'analytics', 'integration'}:
        raise RuntimeError('Unsupported onboarding steps; refusing to proceed')

    client = api.base + '/'
    if 'user' in pending:
        result = api.request('/api/onboarding/users', {
            **owner, 'password': password, 'client_id': client,
        })
        code = result['auth_code']
    else:
        # Resume a partial onboarding with the existing owner. No account reset.
        flow = api.request('/auth/login_flow', {
            'client_id': client, 'handler': ['homeassistant', None],
            'redirect_uri': client,
        })
        result = api.request('/auth/login_flow/' + flow['flow_id'], {
            'client_id': client, 'username': owner['username'], 'password': password,
        })
        if result.get('type') != 'create_entry':
            raise RuntimeError('Existing owner login failed; manual recovery required')
        code = result['result']

    tokens = api.request('/auth/token', {
        'grant_type': 'authorization_code', 'code': code, 'client_id': client,
    }, form=True)
    api.token = tokens['access_token']
    try:
        for step in ('core_config', 'analytics', 'integration'):
            if step in pending:
                data = ({'client_id': client, 'redirect_uri': client}
                        if step == 'integration' else {})
                api.request('/api/onboarding/' + step, data)
        if any(not step['done'] for step in api.status()):
            raise RuntimeError('Onboarding remained incomplete')
        print('HA onboarding complete; initial owner provisioned.')
    finally:
        # Do not retain a privileged automation token after bootstrap.
        api.request('/auth/token', {
            'action': 'revoke', 'token': tokens['refresh_token'],
        }, form=True)
        api.token = None


def main():
    owner = json.loads(os.environ['HA_INITIAL_OWNER'])
    password = (Path(os.environ['CREDENTIALS_DIRECTORY']) / 'owner-password').read_text().strip()
    if not password:
        raise RuntimeError('Empty owner password')
    onboard(API('http://127.0.0.1:8123'), owner, password)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Never print HTTP bodies, payloads, credentials or tokens.
        print('HA onboarding failed: ' + type(error).__name__, file=sys.stderr)
        sys.exit(1)
