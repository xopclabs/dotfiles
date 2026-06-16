import argparse
import asyncio
import logging
import sys
import time
from pathlib import Path
from typing import Any, Dict, Optional, Set
from urllib.parse import quote

import aiohttp
import yaml
from nio import AsyncClient, AsyncClientConfig, RoomMessageText
from nio.events import Event
from nio.events.ephemeral import TypingNoticeEvent
from nio.events.room_events import CallInviteEvent
from nio.responses import SyncResponse
from nio.rooms import MatrixRoom

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
)
log = logging.getLogger('matrix-ntfy-bot')

MESSAGE_PREVIEW_LEN = 120


class BotState:
    def __init__(self) -> None:
        self.sync_ready = False
        self.event_order: Dict[str, Dict[str, int]] = {}
        self.event_counter: Dict[str, int] = {}
        self.typing_until: Dict[str, Dict[str, float]] = {}
        self.watched_rooms: Set[str] = set()
        self.room_names: Dict[str, str] = {}
        self.encrypted_rooms: Set[str] = set()


def load_config(path: Path) -> Dict[str, Any]:
    with path.open(encoding='utf-8') as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError('config must be a YAML mapping')
    for key in ('access_token', 'user_id', 'device_id', 'ntfy_token', 'rooms', 'subscribers'):
        if key not in data:
            raise ValueError(f'missing required config key: {key}')
    return data


def register_event(state: BotState, room_id: str, event_id: str) -> int:
    counter = state.event_counter.get(room_id, 0) + 1
    state.event_counter[room_id] = counter
    state.event_order.setdefault(room_id, {})[event_id] = counter
    return counter


def event_index(state: BotState, room_id: str, event_id: str) -> int:
    return state.event_order.get(room_id, {}).get(event_id, 0)


def user_has_read(
    state: BotState,
    room: MatrixRoom,
    user_id: str,
    message_event: Event,
) -> bool:
    receipt = room.read_receipts.get(user_id)
    if receipt is None:
        return False
    if receipt.event_id == message_event.event_id:
        return True
    read_idx = event_index(state, room.room_id, receipt.event_id)
    msg_idx = event_index(state, room.room_id, message_event.event_id)
    if read_idx > 0 and msg_idx > 0:
        return read_idx >= msg_idx
    return receipt.timestamp >= message_event.server_timestamp


def is_typing(
    state: BotState,
    room_id: str,
    user_id: str,
    grace_seconds: int,
) -> bool:
    until = state.typing_until.get(room_id, {}).get(user_id, 0.0)
    return until > time.time() - grace_seconds


def is_message_edit(event: RoomMessageText) -> bool:
    relates = event.source.get('content', {}).get('m.relates_to', {})
    return relates.get('rel_type') == 'm.replace'


def room_display_name(room: MatrixRoom, configured_name: Optional[str]) -> str:
    if configured_name:
        return configured_name
    return room.display_name or room.room_id


def matrix_to_url(room_id: str) -> str:
    return f'https://matrix.to/#/{quote(room_id, safe="")}'


def truncate(text: str, limit: int = MESSAGE_PREVIEW_LEN) -> str:
    text = text.replace('\n', ' ').strip()
    if len(text) <= limit:
        return text
    return text[: limit - 1] + '…'


async def send_ntfy(
    session: aiohttp.ClientSession,
    ntfy_url: str,
    topic: str,
    token: str,
    title: str,
    message: str,
    click: str,
    icon_url: str,
    priority: str,
) -> None:
    headers = {
        'Authorization': f'Bearer {token}',
        'Title': title,
        'Click': click,
        'Priority': priority,
        'Tags': 'matrix',
    }
    if icon_url:
        headers['Icon'] = icon_url
    url = f'{ntfy_url.rstrip("/")}/{quote(topic, safe="")}'
    async with session.post(url, data=message.encode('utf-8'), headers=headers) as resp:
        if resp.status >= 300:
            body = await resp.text()
            log.warning('ntfy POST %s failed: %s %s', topic, resp.status, body)


async def notify_recipients(
    state: BotState,
    room: MatrixRoom,
    config: Dict[str, Any],
    runtime: Dict[str, Any],
    sender: str,
    event: Event,
    title: str,
    message: str,
    priority: str,
) -> None:
    room_id = room.room_id
    click = matrix_to_url(room_id)
    grace = int(runtime.get('typing_grace_seconds', 30))

    async with aiohttp.ClientSession() as session:
        for subscriber in config['subscribers']:
            matrix_user = subscriber['matrix_user']
            if matrix_user == sender:
                continue
            if user_has_read(state, room, matrix_user, event):
                log.debug('skip %s: already read %s', matrix_user, event.event_id)
                continue
            if is_typing(state, room_id, matrix_user, grace):
                log.debug('skip %s: typing in %s', matrix_user, room_id)
                continue
            await send_ntfy(
                session=session,
                ntfy_url=runtime['ntfy_url'],
                topic=subscriber['ntfy_topic'],
                token=config['ntfy_token'],
                title=title,
                message=message,
                click=click,
                icon_url=runtime.get('icon_url', ''),
                priority=priority,
            )


def make_callbacks(
    state: BotState,
    config: Dict[str, Any],
    runtime: Dict[str, Any],
) -> Any:
    async def on_room_event(room: MatrixRoom, event: Event) -> None:
        if hasattr(event, 'event_id'):
            register_event(state, room.room_id, event.event_id)
        if not state.sync_ready:
            return
        if room.room_id not in state.watched_rooms:
            return
        if event.sender == config['user_id']:
            return

        room_name = room_display_name(room, state.room_names.get(room.room_id))

        if isinstance(event, RoomMessageText):
            if is_message_edit(event):
                return
            sender_name = room.user_name(event.sender) or event.sender
            title = f'{sender_name} · {room_name}'
            body = truncate(event.body)
            await notify_recipients(
                state=state,
                room=room,
                config=config,
                runtime=runtime,
                sender=event.sender,
                event=event,
                title=title,
                message=body,
                priority='default',
            )
            return

        if isinstance(event, CallInviteEvent):
            sender_name = room.user_name(event.sender) or event.sender
            title = f'Call from {sender_name} · {room_name}'
            await notify_recipients(
                state=state,
                room=room,
                config=config,
                runtime=runtime,
                sender=event.sender,
                event=event,
                title=title,
                message='Incoming voice/video call — connect VPN to answer',
                priority='urgent',
            )

    async def on_typing(room: MatrixRoom, event: TypingNoticeEvent) -> None:
        now = time.time()
        grace = int(runtime.get('typing_grace_seconds', 30))
        until = state.typing_until.setdefault(room.room_id, {})
        for user_id in event.users:
            until[user_id] = now + grace

    async def on_sync_response(response: Any) -> None:
        if not state.sync_ready:
            state.sync_ready = True
            log.info('initial sync complete; processing new events only')

    return on_room_event, on_typing, on_sync_response


def setup_client(
    config: Dict[str, Any],
    runtime: Dict[str, Any],
    state: BotState,
) -> AsyncClient:
    homeserver = runtime.get(
        'homeserver',
        f'http://127.0.0.1:{runtime.get("synapse_port", 8098)}',
    )
    store_path = Path(runtime['store_path'])

    client_config = AsyncClientConfig(store_sync_tokens=True)
    client = AsyncClient(
        homeserver,
        config['user_id'],
        device_id=config['device_id'],
        config=client_config,
        store_path=str(store_path),
    )
    client.access_token = config['access_token']

    on_room_event, on_typing, on_sync_response = make_callbacks(state, config, runtime)

    client.add_event_callback(on_room_event, (RoomMessageText, CallInviteEvent))
    client.add_ephemeral_callback(on_typing, TypingNoticeEvent)
    client.add_response_callback(on_sync_response, SyncResponse)
    return client


async def run_bot(config_path: Path, runtime: Dict[str, Any]) -> None:
    config = load_config(config_path)
    state = BotState()

    for room in config['rooms']:
        state.watched_rooms.add(room['room_id'])
        state.room_names[room['room_id']] = room.get('name', '')
        if room.get('encrypted', False):
            state.encrypted_rooms.add(room['room_id'])

    client = setup_client(config, runtime, state)

    log.info(
        'starting matrix-ntfy-bot for %s (%d rooms, %d subscribers)',
        config['user_id'],
        len(state.watched_rooms),
        len(config['subscribers']),
    )

    await client.sync_forever(timeout=30000, full_state=True)


def main() -> None:
    parser = argparse.ArgumentParser(description='Matrix room events to ntfy push')
    parser.add_argument('config', type=Path, help='YAML config file path')
    parser.add_argument(
        '--ntfy-url',
        required=True,
        help='Public ntfy base URL (e.g. https://ntfy.example.com)',
    )
    parser.add_argument(
        '--homeserver',
        default='http://127.0.0.1:8098',
        help='Synapse client API URL reachable from this host',
    )
    parser.add_argument(
        '--store-path',
        type=Path,
        default=Path('/var/lib/matrix-ntfy-bot'),
        help='Persistent matrix-nio store directory',
    )
    parser.add_argument(
        '--icon-url',
        default='https://matrix.org/images/matrix-logo.png',
        help='Notification icon URL (PNG/JPEG)',
    )
    parser.add_argument(
        '--typing-grace-seconds',
        type=int,
        default=30,
        help='Skip notify if user typed in room within this many seconds',
    )
    args = parser.parse_args()

    runtime = {
        'ntfy_url': args.ntfy_url,
        'homeserver': args.homeserver,
        'store_path': str(args.store_path),
        'icon_url': args.icon_url,
        'typing_grace_seconds': args.typing_grace_seconds,
    }

    try:
        asyncio.run(run_bot(args.config, runtime))
    except KeyboardInterrupt:
        log.info('stopped')
        sys.exit(0)


if __name__ == '__main__':
    main()
