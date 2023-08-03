Automates creating a systemd-nspawn container
Requires that you run a debian linux distribution, with systemd as init. systemd-container and debootstrap apt packages must both be installed

Usage:
sudo ./do_chroot.sh init <container-name> <project-name (default template)> <-b some-distribution-name>
sudo ./do_chroot.sh remove <container-name>
sudo ./do_chroot.sh <whatever> <container-name> <-p>

Note: Scripts RUN AS ROOT when done through this process. Make sure that you fully trust EVERY file that is present in templates.
Note: For this to work, whatever is in projects/project-name/start/init must at least install systemd.

init: generates a new chroot
Note that both chroot names and actions can only have the characters a-zA-Z0-9_-
Effects:
 - If chroots/ does not exist, creates it
 - Creates a chroots/container-name directory
 - Adds debian files to chroots-container-name
 - Appends 'container-name project-name' to config.txt
 - Runs the script in projects/project-name/outside/init.sh (if it exists)
 - If there is a script projects/project-name/before_copy/init, copies it into /root/before_copy in the chroot and runs it as root from the context of the chroot
 - Copies all files listed in projects/project-name/copy/init.cp into the chroot as specified (if it exists) (see template - file format is self evident)
 - If there is a script projects/project-name/start/init, copies it into /root/init in the chroot and runs it as root from the context of the chroot
remove: removes a chroot
Effects:
 - Removes chroots/container-name
 - Removes the line in config.txt where the first column is container-name
whatever: starts systemd-nspawn
Effects:
 - Runs the script in projects/project-name/outside/whatever.sh - this modifies the chroot permanently (if it exists)
  - If there is a script projects/project-name/before_copy/whatever, copies it into /root/whatever in the chroot and runs it as root from the context of the chroot - this modifies the chroot permanently
 - Copies all files listed in projects/project-name/copy/whatever.cp into the chroot as specified - this modifies the chroot permanently (if it exists)
 - If there is a script projects/project-name/start/whatever, copies it into /root/whatever in the chroot and runs it as root from the context of the chroot - this modifies the chroot permanently
 - Runs systemd-nspawn with systemd init process (requires the chroot to have installed systemd) in an ephemeral directory. If -p is specified, changes made in the chroot are persistent
