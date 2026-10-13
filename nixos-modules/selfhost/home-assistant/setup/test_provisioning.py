import unittest
from unittest.mock import patch

from provisioning import reconcile_users


class FakeAPI:
    base = 'http://127.0.0.1:8123'

    def __init__(self, users=None):
        self.users = users or []
        self.calls = []

    def ws(self, command, **fields):
        self.calls.append((command, fields))
        if command == 'config/auth/list':
            return self.users
        if command == 'config/auth/create':
            return {'user': {'id': 'remote-id'}}
        if command == 'auth/current_user':
            return {'id': 'remote-id', 'is_admin': False, 'is_owner': False}
        return None

    def request(self, *args, **kwargs):
        self.calls.append(('request', kwargs))
        return {}


class UsersTests(unittest.TestCase):
    config = {'esp32-remote': {'name': 'ESP32 Remote', 'password': 'test-password'}}

    def reconcile(self, api):
        remote = FakeAPI()
        with patch('provisioning.ProvisionAPI', return_value=remote), patch('provisioning.login',
                return_value={'refresh_token': 'test-refresh-token'}) as login:
            reconcile_users(api, self.config)
        self.assertEqual(login.call_count, 1)
        self.assertEqual(remote.calls[-1][0], 'request')

    def test_create_nonadmin_local_only(self):
        api = FakeAPI()
        self.reconcile(api)
        self.assertIn(('config/auth/create', {'name': 'ESP32 Remote',
            'group_ids': ['system-users'], 'local_only': True}), api.calls)
        self.assertIn(('config/auth_provider/homeassistant/create', {
            'user_id': 'remote-id', 'username': 'esp32-remote', 'password': 'test-password'}), api.calls)

    def test_existing_identity_and_password_preserved(self):
        api = FakeAPI([{'id': 'remote-id', 'username': 'esp32-remote', 'name': 'ESP32 Remote',
            'group_ids': ['system-users'], 'local_only': True, 'is_owner': False}])
        self.reconcile(api)
        self.assertEqual([call[0] for call in api.calls], ['config/auth/list'])

    def test_owner_not_adopted(self):
        api = FakeAPI([{'id': 'owner', 'username': 'esp32-remote', 'is_owner': True}])
        with self.assertRaises(RuntimeError):
            reconcile_users(api, self.config)
        self.assertEqual(len(api.calls), 1)

    def test_conflicting_display_name_not_adopted(self):
        api = FakeAPI([{'name': 'ESP32 Remote', 'username': 'another-user'}])
        with self.assertRaises(RuntimeError):
            reconcile_users(api, self.config)
        self.assertEqual(len(api.calls), 1)

    def test_drift_reconciles_without_resetting_password(self):
        api = FakeAPI([{'id': 'remote-id', 'username': 'esp32-remote', 'name': 'Old name',
            'group_ids': ['system-admin'], 'local_only': False}])
        self.reconcile(api)
        self.assertEqual(api.calls[-1], ('config/auth/update', {'user_id': 'remote-id',
            'name': 'ESP32 Remote', 'group_ids': ['system-users'], 'local_only': True}))


if __name__ == '__main__':
    unittest.main()
