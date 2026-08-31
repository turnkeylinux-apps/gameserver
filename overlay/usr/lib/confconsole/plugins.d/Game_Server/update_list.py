"""Update the verified game-server catalog and LinuxGSM bootstrap."""

import subprocess


def run():
    console.infobox('Checking the official game-server update channels...')
    result = subprocess.run(
        ['/usr/local/sbin/turnkey-gameserver-update', '--apply'],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        console.msgbox(
            'Update Error',
            'The game-server catalog update failed:\n' + result.stderr,
        )
        return

    console.msgbox('Update', result.stdout)
