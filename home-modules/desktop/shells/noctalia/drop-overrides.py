import re
import sys
from pathlib import Path
from typing import List


HEADERS: List[str] = [
    '[widget.taskbar]',
    '[widget.workspaces]',
    '[control_center]',
    '[shell.mpris]',
]

KEYS: List[str] = [
    'app_icon_colorize',
    'app_icon_color',
    'app_icon_curve',
]


def drop_overrides(settings_path: Path) -> None:
    if not settings_path.is_file():
        return
    text = settings_path.read_text(encoding='utf-8')
    for header in HEADERS:
        text = re.sub(
            r'(?ms)^' + re.escape(header) + r'\n.*?(?=^\[|\Z)',
            '',
            text,
        )
    for key in KEYS:
        text = re.sub(r'(?m)^' + re.escape(key) + r' = .*\n', '', text)
    settings_path.write_text(text, encoding='utf-8')


def main() -> None:
    if len(sys.argv) > 1:
        drop_overrides(Path(sys.argv[1]))


if __name__ == '__main__':
    main()
