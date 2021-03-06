GameServer - Host your own game server
=======================================================

GameServer is a `TurnKey GNU/Linux`_ appliance for hosting
game servers on Linux. It provides a way of deploying game servers
in minutes in cloud environments or local VMs.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Managing game servers using `Linux Gameservers`_:

   - Downloads newest version during first boot to ensure best possible game
     support.
   - Wrapper for `LinuxGSM`_ with support for up to 100 games.

- Fully automatic or interactive game server selection:

   - All required settings can be passed via user data, game server starts
     within minutes.
   - If no data is provided, graphical interface will prompt user to select
     required game server.

**Note:** For further initial usage info, please see the `usage docs`_.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, Shellinabox: username **root**
-  Game server: username **gameuser**

.. _TurnKey GNU/Linux: https://www.turnkeylinux.org/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Linux Gameservers: https://github.com/jesinmat/linux-gameservers
.. _LinuxGSM: https://linuxgsm.com/
.. _usage docs: https://github.com/turnkeylinux-apps/gameserver/tree/master/docs/usage.rst
