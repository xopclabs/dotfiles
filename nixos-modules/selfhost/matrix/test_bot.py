import tempfile
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


if __name__ == '__main__':
    unittest.main()
