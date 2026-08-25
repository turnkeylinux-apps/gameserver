#!/usr/bin/python3
"""Set Gameserver Repo and Branch

Options:
    --gameserver-repo=      unless provided, will ask interactively
    --gameserver-branch=    unless provided, will ask interactively

"""
import os
import sys
import getopt
import shutil
import subprocess
import tempfile
from libinithooks.dialog_wrapper import Dialog

DEFAULT_GAMESERVER_REPO = 'https://github.com/jesinmat/linux-gameservers.git'
DEFAULT_GAMESERVER_BRANCH = 'master'
GAME_REPO_DIR = '/root/gameservers'
SOURCE_RECORD = '/usr/local/share/turnkey-gameserver/source'

def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print('Syntax: %s [options]' % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], 'h',
                ['help', 'gameserver-repo=', 'gameserver-branch='])
    except getopt.GetoptError as e:
        usage(e)

    gameserver_repo = ""
    gameserver_branch = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--gameserver-repo':
            gameserver_repo = val
        elif opt == '--gameserver-branch':
            gameserver_branch = val

    dialog = Dialog('TurnKey Linux - First boot configuration')

    if not gameserver_repo or not gameserver_branch:
        choose_gameserver_upstream = dialog.yesno(
                'TKL Gameserver',
                'Do you want to choose a custom repo?')
        if choose_gameserver_upstream:
            if not gameserver_repo:
                ok, gameserver_repo = dialog.inputbox(
                    'TKL Gameserver',
                    'Choose gameserver repo url',
                    DEFAULT_GAMESERVER_REPO)
                if not ok:
                    gameserver_repo = DEFAULT_GAMESERVER_REPO
            if not gameserver_branch:
                ok, gameserver_branch = dialog.inputbox(
                    'TKL Gameserver',
                    'Choose gameserver branch',
                    DEFAULT_GAMESERVER_BRANCH)
                if not ok:
                    gameserver_branch = DEFAULT_GAMESERVER_BRANCH

        else:
            gameserver_repo = DEFAULT_GAMESERVER_REPO
            gameserver_branch = DEFAULT_GAMESERVER_BRANCH

    if (gameserver_repo, gameserver_branch) == (
            DEFAULT_GAMESERVER_REPO, DEFAULT_GAMESERVER_BRANCH):
        return

    temp_dir = tempfile.mkdtemp(prefix='.gameservers-', dir='/root')
    candidate_dir = os.path.join(temp_dir, 'repo')
    try:
        subprocess.run([
            'git', 'clone', '--depth=1', '--branch', gameserver_branch,
            gameserver_repo, candidate_dir,
        ], check=True)
        if not os.path.isfile(os.path.join(candidate_dir, 'auto_install.sh')):
            raise RuntimeError('custom repository has no auto_install.sh')
        if not os.path.isdir(os.path.join(candidate_dir, 'games')):
            raise RuntimeError('custom repository has no games directory')
        commit = subprocess.run([
            'git', '-C', candidate_dir, 'rev-parse', 'HEAD',
        ], check=True, capture_output=True, text=True).stdout.strip()

        shutil.rmtree(GAME_REPO_DIR)
        os.replace(candidate_dir, GAME_REPO_DIR)
        with open(SOURCE_RECORD, 'w', encoding='utf-8') as source_record:
            source_record.write(
                'wrapper_channel=custom git repository\n'
                f'wrapper_repository={gameserver_repo}\n'
                f'wrapper_ref={gameserver_branch}\n'
                f'wrapper_commit={commit}\n'
                'linuxgsm_channel=custom wrapper policy\n'
            )
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

if __name__ == '__main__':
    main()
