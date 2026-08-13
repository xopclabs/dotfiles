import tempfile
import time
import unittest
from pathlib import Path
from typing import Any, Dict
from unittest.mock import AsyncMock, patch

from nio.events.ephemeral import TypingNoticeEvent
from nio.events.room_events import CallInviteEvent, RoomMessageText
from nio.responses import SyncResponse

import bot

HS = 'example.com'
SAMPLE_TOKEN = 'tk_vntbqomzld1g4q5vd1k1jgtmds4l7'

SAMPLE_CONFIG = f'''\
access_token: syt_test
user_id: "@ntfy-bot:matrix.{HS}"
device_id: NTFYBOT
rooms:
  - room_id: "!room:matrix.{HS}"
    encrypted: false
    name: Family
subscribers:
  - matrix_user: "@alice:matrix.{HS}"
    ntfy_topic: fam-alice-test
'''


def write_config(content: str = SAMPLE_CONFIG) -> Path:
    handle = tempfile.NamedTemporaryFile('w', suffix='.yaml', delete=False)
    handle.write(content)
    handle.close()
    return Path(handle.name)


class LoadConfigTest(unittest.TestCase):
    def test_loads_valid_config(self) -> None:
        path = write_config()
        config = bot.load_config(path, SAMPLE_TOKEN)
        self.assertEqual(config['user_id'], f'@ntfy-bot:matrix.{HS}')
        self.assertEqual(config['ntfy_token'], SAMPLE_TOKEN)

    def test_loads_token_from_yaml(self) -> None:
        path = write_config(
            'access_token: x\nuser_id: "@b:s"\ndevice_id: D\nntfy_token: tk_yaml\nrooms: []\nsubscribers: []\n'
        )
        config = bot.load_config(path)
        self.assertEqual(config['ntfy_token'], 'tk_yaml')

    def test_rejects_missing_keys(self) -> None:
        path = write_config('access_token: only\n')
        with self.assertRaises(ValueError):
            bot.load_config(path)


class SetupClientTest(unittest.TestCase):
    def test_registers_matrix_nio_callbacks(self) -> None:
        config = bot.load_config(write_config(), SAMPLE_TOKEN)
        state = bot.BotState()
        runtime: Dict[str, Any] = {
            'homeserver': 'http://127.0.0.1:8098',
            'store_path': tempfile.mkdtemp(),
            'ntfy_url': 'https://ntfy.example.com',
            'ntfy_token': SAMPLE_TOKEN,
            'icon_url': '',
            'typing_grace_seconds': 30,
        }

        with patch.object(bot, 'AsyncClient') as mock_client_cls:
            mock_client = mock_client_cls.return_value
            client = bot.setup_client(config, runtime, state)

        mock_client_cls.assert_called_once()
        mock_client.add_event_callback.assert_called_once()
        _, event_filter = mock_client.add_event_callback.call_args.args
        self.assertEqual(event_filter, (RoomMessageText, CallInviteEvent))

        mock_client.add_ephemeral_callback.assert_called_once()
        _, ephemeral_filter = mock_client.add_ephemeral_callback.call_args.args
        self.assertEqual(ephemeral_filter, TypingNoticeEvent)

        mock_client.add_response_callback.assert_called_once()
        _, response_filter = mock_client.add_response_callback.call_args.args
        self.assertEqual(response_filter, SyncResponse)
        self.assertIs(client, mock_client)


class RunBotTest(unittest.IsolatedAsyncioTestCase):
    async def test_run_bot_reaches_sync_forever(self) -> None:
        path = write_config()
        runtime: Dict[str, Any] = {
            'homeserver': 'http://127.0.0.1:8098',
            'store_path': tempfile.mkdtemp(),
            'ntfy_url': 'https://ntfy.example.com',
            'ntfy_token': SAMPLE_TOKEN,
            'icon_url': '',
            'typing_grace_seconds': 30,
        }

        with patch.object(bot, 'AsyncClient') as mock_client_cls:
            mock_client = mock_client_cls.return_value
            mock_client.sync_forever = AsyncMock()
            await bot.run_bot(path, runtime)

        mock_client.sync_forever.assert_awaited_once_with(timeout=30000, full_state=True)


PAVEL_PUBKEY = 'h/zTkj0tEVTYjJYZ3mvNLBblkKD9XMq7UpR03dlWSxo='
PAVEL_PC_PUBKEY = 'dgkPzUZ+R3ODZWzY46DROU7VOOvuvndJucQlWEu0UV0='
DAD_PUBKEY = 'oeVcaSF66inhr7nLpofaYeqUL3+rtH/tAaiK8HJn2nY='
PEER_KEYS = {
    'pavel': PAVEL_PUBKEY,
    'pavel-pc': PAVEL_PC_PUBKEY,
    'dad': DAD_PUBKEY,
}
PAVEL = {
    'matrix_user': f'@pavel:matrix.{HS}',
    'ntfy_topic': 'matrix-pavel',
}


class WgHandshakeTest(unittest.TestCase):
    def test_parse_latest_handshakes(self) -> None:
        output = (
            f'{PAVEL_PUBKEY}\t1786626230\n'
            f'{DAD_PUBKEY} 0\n'
            'not-a-valid-line\n'
        )
        self.assertEqual(
            bot.parse_latest_handshakes(output),
            {PAVEL_PUBKEY: 1786626230, DAD_PUBKEY: 0},
        )

    def test_peer_is_connected_fresh_handshake(self) -> None:
        now = 1_000_180.0
        handshakes = {PAVEL_PUBKEY: 1_000_000}
        self.assertTrue(
            bot.peer_is_connected(handshakes, PAVEL_PUBKEY, now, 180)
        )

    def test_peer_is_connected_stale_or_missing(self) -> None:
        now = 1_000_181.0
        handshakes = {PAVEL_PUBKEY: 1_000_000, DAD_PUBKEY: 0}
        self.assertFalse(
            bot.peer_is_connected(handshakes, PAVEL_PUBKEY, now, 180)
        )
        self.assertFalse(
            bot.peer_is_connected(handshakes, DAD_PUBKEY, now, 180)
        )
        self.assertFalse(
            bot.peer_is_connected(handshakes, PAVEL_PC_PUBKEY, now, 180)
        )

    def test_matrix_localpart(self) -> None:
        self.assertEqual(
            bot.matrix_localpart(f'@pavel:matrix.{HS}'),
            'pavel',
        )

    def test_subscriber_wg_keys_auto_localpart(self) -> None:
        self.assertEqual(
            bot.subscriber_wg_keys(PAVEL, PEER_KEYS),
            [PAVEL_PUBKEY],
        )

    def test_subscriber_wg_keys_explicit_peers(self) -> None:
        subscriber = dict(PAVEL, wg_peers=['pavel', 'pavel-pc'])
        self.assertEqual(
            bot.subscriber_wg_keys(subscriber, PEER_KEYS),
            [PAVEL_PUBKEY, PAVEL_PC_PUBKEY],
        )

    def test_subscriber_on_vpn_matches_phone_not_desktop(self) -> None:
        now = 1_000_000.0
        phone_up = {PAVEL_PUBKEY: 999_900, PAVEL_PC_PUBKEY: 0}
        desktop_only = {PAVEL_PUBKEY: 0, PAVEL_PC_PUBKEY: 999_900}
        self.assertTrue(
            bot.subscriber_on_vpn(PAVEL, PEER_KEYS, phone_up, 180, now)
        )
        self.assertFalse(
            bot.subscriber_on_vpn(PAVEL, PEER_KEYS, desktop_only, 180, now)
        )

    def test_load_wg_peer_keys(self) -> None:
        path = write_config('{"pavel": "abc=", "dad": "def="}\n')
        self.assertEqual(
            bot.load_wg_peer_keys(path),
            {'pavel': 'abc=', 'dad': 'def='},
        )
        self.assertEqual(bot.load_wg_peer_keys(None), {})


class NotifyVpnSkipTest(unittest.IsolatedAsyncioTestCase):
    def _runtime(self) -> Dict[str, Any]:
        return {
            'ntfy_url': 'https://ntfy.example.com',
            'typing_grace_seconds': 30,
            'wg_bin': 'wg',
            'wg_interface': 'wg0',
            'wg_peer_keys': PEER_KEYS,
            'wg_handshake_timeout': 180,
            'icon_url': '',
        }

    async def _notify(self, handshakes: Dict[str, int]) -> AsyncMock:
        config = bot.load_config(write_config(), SAMPLE_TOKEN)
        config['subscribers'] = [PAVEL]
        room = type('Room', (), {'room_id': f'!room:matrix.{HS}', 'read_receipts': {}})()
        event = type('Event', (), {'event_id': '$e', 'server_timestamp': 1})()
        send = AsyncMock()
        with patch.object(bot, 'read_wg_handshakes', AsyncMock(return_value=handshakes)):
            with patch.object(bot, 'send_ntfy', send):
                await bot.notify_recipients(
                    state=bot.BotState(),
                    room=room,
                    config=config,
                    runtime=self._runtime(),
                    sender=f'@dad:matrix.{HS}',
                    event=event,
                    title='t',
                    message='m',
                    priority='default',
                )
        return send

    async def test_skips_when_on_vpn(self) -> None:
        send = await self._notify({PAVEL_PUBKEY: int(time.time())})
        send.assert_not_called()

    async def test_sends_when_offline_vpn(self) -> None:
        send = await self._notify({PAVEL_PUBKEY: 0})
        send.assert_awaited_once()
        self.assertEqual(send.await_args.kwargs['message'], 'm')


if __name__ == '__main__':
    unittest.main()
