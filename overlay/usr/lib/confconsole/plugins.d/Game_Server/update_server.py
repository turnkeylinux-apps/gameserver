'''Update game server version'''
import os
import subprocess

GAME_REPO_DIR="/root/gameservers"
SERVER_NAME_FILE = "/etc/gameserver/gameserver"

def get_game_code():
    try:
        with open(SERVER_NAME_FILE, 'r') as file:
            for line in file:
                if line.startswith("GAME="):
                    game_code = line.split('=')[1].strip().strip('"')
                    return game_code
    except FileNotFoundError:
        return ('error', f'File not found: {SERVER_NAME_FILE}')
    except Exception as e:
        return ('error', str(e))

def run():
    if not os.path.exists('/etc/gameserver/installation.done'):
            console.msgbox('Info', 'No game server is installed')
            return

    console.msgbox('Info', 'The game server will be redownloaded and installed, even if no update is available.')

    curdir = os.getcwd()
    os.chdir(GAME_REPO_DIR)

    game_code = get_game_code()

    console.infobox('Stopping the game server')
    ret = subprocess.run(['systemctl', 'stop', 'gameserver'], capture_output=True, text=True)
    if ret.returncode != 0:
        console.msgbox('Error', 'An error occurred while stopping the game server:\n' + ret.stderr)
        os.chdir(curdir)
        return

    console.infobox('Attemting to update game server. Be patient, this takes at least a few minutes...')
    ret = subprocess.run(
            ['./auto_install.sh', '-g', game_code, '-u', 'gameuser', '-p', '/home/gameuser/gameserver'], 
            capture_output=True, text=True)
    if ret.returncode != 0:
        console.msgbox('Error', 'An error occurred during the update (will attempt to restart the server regardless):\n' + ret.stderr)

    console.infobox('Restarting the game server')
    ret = subprocess.run(['systemctl', 'start', 'gameserver'], capture_output=True, text=True)
    if ret.returncode != 0:
        console.msgbox('Error', 'An error occurred while starting the game server:\n' + ret.stderr)
    else:
        console.msgbox('Update', 'Update success')

    os.chdir(curdir)
