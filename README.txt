Automates creating a systemd-nspawn container
Requires that you run a debian linux distribution, with systemd as init. systemd-container and debootstrap apt packages must both be installed

Usage:
./do_chroot_wrapper init <container-name> <project-name (default template)> <-b some-distribution-name>
./do_chroot_wrapper remove <container-name>
./do_chroot_wrapper <whatever> <container-name> <-p>

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


Copy script commands (affects the base instance):
 - // perms: 744 : This changes the permissions of all files in the directory (but not the permissions of the directory) to 744
 - // folder-perms: 775 : This changes the permissions of all directories to 775 recursively
 - // owned: foo:foo_group : This recursively changes the user and group ownership of the file/directory. foo changes user ownership of the directory to foo, :foo_group changes group ownership to foo_group. Users and groups are read from the chroot, not the home machine. You can also use numbers, like 0:0 to change ownership to root.
 - // linked : All files recursively present in the directory (not the directories themselves) will be hard linked to the files in projects/. This means that files in the persistent chroot (-p) will change when files in the projects/directory are changed, without needing to reload the container. Using // perms: or // owned: with this command will also change the permissions of the files in projects/. New files created in the directory will not be automatically updated, and copy and move commands will not affect the linkage (or create new links).
 - // glob : This filepath is globbed. In this case, the destination MUST refer to an existing directory in the chroot, and all globbed files will be placed in the directory under the same name as they are in data/.
 
Bash completion:
To enable bash completion (using TAB in bash to automatically complete commands), read the initial comment and run the .bash_completions script. The AUTOMATED_NSPAWN_DIRECTORY variable will have to be set.