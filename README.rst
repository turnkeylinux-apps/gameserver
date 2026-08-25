GameServer - Host your own game server
=======================================================

GameServer is a `TurnKey GNU/Linux`_ headless server appliance for hosting
game servers on Linux. Choose from up to `100 different game servers`_ to
deploy to the cloud or local VM in minutes.

Host a game server in minutes. Supports installation of a huge range of game
servers, including Counter-Strike (Source & other CS titles), a range of Call
of Duty titles, Minecraft, GTA: San Andreas, Quake III, a number of Unreal
Tournament titles, plus many others.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Managing game servers using `Linux Gameservers`_:

   - Installs a verified game catalog and LinuxGSM stable release.
   - Wrapper for `LinuxGSM`_ with support for more than 100 game servers.
   - ``turnkey-gameserver-update`` checks or applies verified catalog and
     LinuxGSM updates. Individual game servers retain their LinuxGSM update
     command.

- Fully automatic or interactive game server selection:

   - All required settings can be passed via user data, game server starts
     within minutes.
   - If no data is provided, graphical interface will prompt user to select
     required game server.

**Note:** For further initial usage info, please see the `usage docs`_.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH: username **root**
-  Game server: username **gameuser**

.. _TurnKey GNU/Linux: https://www.turnkeylinux.org/
.. _100 different game servers: https://github.com/jesinmat/linux-gameservers#supported-games
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Linux Gameservers: https://github.com/jesinmat/linux-gameservers
.. _LinuxGSM: https://linuxgsm.com/
.. _usage docs: https://github.com/turnkeylinux-apps/gameserver/tree/master/docs/usage.rst
