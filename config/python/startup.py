import os
import atexit
import readline
from pathlib import Path

def setup_history():

    if state_home := os.environ.get('XDG_STATE_HOME'):
        state_home = Path(state_home) / 'python'
    else:
        state_home = Path.home() / '.local' / 'state' / 'python'

    history: Path = state_home / 'history'

    # First run on a fresh machine: the directory and file don't exist yet
    state_home.mkdir(parents=True, exist_ok=True)
    try:
        readline.read_history_file(str(history))
    except (FileNotFoundError, OSError):
        pass
    atexit.register(readline.write_history_file, str(history))

if not hasattr(__builtins__, '__IPYTHON__'):
    setup_history()
