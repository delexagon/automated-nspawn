idk

parts:
copy from one place to another - COMPLETE
a description of the changes that bring a computer to a state - NOT STARTED
set up the chroot directory - COMPLETE

These are the defined directories and files, which are used DIRECTLY by the chroot script:
start_predefined/ -> $STARTERS internal scripts 
  init.sh - automatically run during initialization (from /root)
  reload.sh - run any time the container is restarted (from /root)
data/ -> $DATA, all the files present on the pc, mapped by a copy file
copy/ -> $COPY, descriptions of where to copy files
  predefined/
    init.sh - copies everything during initialization
    reload.sh - copied whenever the container is restarted
outside/ -> $OUTSIDE scripts occurring outside of the context of the box
  predefined/
    init.sh - run once
    reload.sh - run every time 
  
order: outside runs -> copy runs -> script runs

what do we need to initialize the computer?
- a list of files, and where they are
- a list of commands to run
