Usage
=====

Interactive installation
------------------------

When running this appliance with an interactive output (such as in a local
virtual machine), you will be guided through the game server installation
using a graphical interface.

During the installation, you will be asked to provide basic server settings for
the game server.

If for some reason the install is interupted or fails, but reports success;
please remove /etc/gameserver/installation.done and retry. I.e.::

   rm /etc/gameserver/installation.done
   gameserver-init


Manual headless installation
----------------------------

If you're launching this appliance in a cloud environment without providing
user data (see next chapter for details about user data), you will need to
log into the server using SSH and start the game server installation either
in the Configuration Console menu (``confconsole``) or by using the
``gameserver-init`` command. An interactive interface will guide you through
the installation.

Automatic headless installation
-------------------------------

On supported platforms, user data can be passed to the image before the first
boot. Cloud service providers offer ways to run scripts before launching the
instance, enabling the user to set the environment. You can use
`supported environment variables`_ from Linux Gameservers to initialize your
game server without user interaction. Password for the **gameuser** account
can be set through the ``APP_PASS`` variable.

Below is a sample init script::

    #!/bin/bash

    cat>/etc/inithooks.conf<<EOF
    export ROOT_PASS=YourSecretRootPassword
    export DB_PASS=YourSecretMysqlPassword
    export APP_PASS=YourSecretWebappAndGameuserPassword
    export APP_EMAIL=admin@example.com
    export HUB_APIKEY=SKIP
    export SEC_UPDATES=FORCE

    export GAME="mc"
    export GAME_SERVER_NAME="My first Minecraft game server"
    EOF

In case you don't specify the ``GAME`` variable, you can choose a game server
later by logging into the appliance and following the guide in `Manual headless
installation`_.

Update gameserver list
----------------------------

If a game on the `supported games <https://github.com/jesinmat/linux-gameservers/tree/master#supported-games>`_ list is missing, you need to update the gameserver list. There are two methods to update the gameserver list, through the Configuration Console or updating the repo from the CLI.



Method 1:
^^^^^^^^^^^

#. SSH into the appliance and run the command ``confconsole``.

#. Select ``Advanced`` menu or press the ``A`` key and then <Enter>.

#. Select ``Gameserver`` or press the ``G`` key and then <Enter>.

#. Select ``Update list`` or press the ``U`` key and then <Enter>.

#. Done!

Method 2:
^^^^^^^^^^^

#. SSH into the appliance and stop the service::

    ~# systemctl stop gameserver

#. Change to gameservers directory::

    ~# cd /root/gameservers/

#. Pull down the latest from the git repo::

    ~/gameservers# git pull origin master

#. Start the gameserver service::

    ~/gameservers# systemctl start gameserver
    
Done!

Update game server version
----------------------------
If there is an update to the game after deploying your server, you may need to update the server to allow clients with the newer version to connect. Like with updating the game server list, this can either be done through the GUI or manually. Here are instructions for the two methods:

Method 1:
^^^^^^^^^^^

#. SSH into the appliance and run the command ``confconsole``.

#. Select ``Advanced`` menu or press the ``A`` key and then <Enter>.

#. Select ``Gameserver`` or press the ``G`` key and then <Enter>.

#. Select ``Update server`` or press the ``U`` key **twice** and then <Enter>.

#. Be patient, the update can take a few minutes.

#. Done!

Method 2:
^^^^^^^^^^^

#. Find your installed game server on the `supported games <https://github.com/jesinmat/linux-gameservers/tree/master#supported-games>`_ list. You will need the "Code" shown in this list.

#. SSH into the appliance and stop the service::

    ~# systemctl stop gameserver

#. Change to gameservers directory::

    ~# cd /root/gameservers/

#. Update your game server (replace ``<CODE>`` with the Code from step 1)::

    ~# ./auto_install.sh -g <CODE> -u gameuser -p /home/gameuser/gameserver

   e.g. for a Satisfactory server (code ``sf``)

    ``~# ./auto_install.sh -g sf -u gameuser -p /home/gameuser/gameserver``

#. Start the game server back up::

    ~# ./sfserver start

The server should now be updated to the latest version of the game.

Logs
----

Game server installation logs are stored in
``/var/log/gameserver/install.log``. Other game server logs, as well as the
server itself, are stored in ``/home/gameuser/gameserver/``.

.. _supported environment variables: https://github.com/jesinmat/linux-gameservers#supported-games
