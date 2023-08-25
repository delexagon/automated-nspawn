#!/bin/bash
is_production=

if [ ! "$EUID" = "0" ] ; then
  echo "Not root"
  exit 1
fi

run_script_in_chroot() {
  if [ "$is_production" ] ; then
    "$1"
  else
    systemd-nspawn -D "$THIS_CHROOT" -a "$1"
  fi
}

do_special() {
  if [ "$1" = init ] ; then
    if ! python3 make_chroot.py "chroots" "$CHROOT_NAME" "$DISTRIBUTION" ; then
      echo "Making chroot failed"
      exit 1
    fi
  elif [ "$1" = remove ] ; then
    rm -rf "$THIS_CHROOT"
    exit 0
  else
    if ! [ -d "$THIS_CHROOT" ] ; then
      echo "Error: $THIS_CHROOT does not exist"
      exit 1
    fi
  fi
}

do_automatic() {
  if [ -f "$OUTSIDE/$1" ] ; then
    bash "$OUTSIDE/$1"
  fi
  if [ -f "$BEFORE_COPY/$1" ] ; then
    cp "$BEFORE_COPY/$1" "$THIS_CHROOT/root/$1"
    chmod 500 "$THIS_CHROOT/root/$1"
    run_script_in_chroot "/root/$1"
  fi
  if [ -f "$COPY/$1" ] ; then
    python3 copy_files.py "$DATA" "$THIS_CHROOT" "$COPY/$1" "$THIS_CHROOT/etc/passwd" "$THIS_CHROOT/etc/group"
  fi
  if [ -f "$STARTERS/$1" ] ; then
    cp "$STARTERS/$1" "$THIS_CHROOT/root/$1"
    chmod 500 "$THIS_CHROOT/root/$1"
    run_script_in_chroot "/root/$1"
  fi
  if [ -f "$AFTER/$1" ] ; then
    bash "$AFTER/$1"
  fi
}

if [ ! -e 'chroots' ] ; then
  mkdir chroots
fi

# Expectations: do_chroot.sh name_of_chroot init <-b build>
# Expectations: do_chroot.sh name_of_chroot load
# Expectations: do_chroot.sh name_of_chroot remove

CHROOT_NAME="$1"

if ! [[ "$CHROOT_NAME" =~ ^[a-zA-Z0-9_-]*$ ]] ; then
  echo "Invalid chroot name"
  exit 1
fi

shift 1
export THIS_CHROOT=$(realpath chroots/"$CHROOT_NAME")

# Unfortunately, we assume our chroot name is the same as our project name.
export PROJECT_NAME="$CHROOT_NAME"
export THIS_PROJECT=$(realpath projects/"$PROJECT_NAME")
if [ ! -d "$THIS_PROJECT" ] ; then
  echo "Project $THIS_PROJECT does not exist"
  exit 1
fi

# Export project files

# A script. Expected to set bash variables, run as source here.
export CONFIG="$THIS_PROJECT"/config.sh
# Data should have all files necessary for the project to be run
export DATA="$THIS_PROJECT"/data

# In order of when scripts are run. 'Outside' and 'After' are run outside the chroot,
# 'Before_copy' and 'Starters' are run in the chroot before and after copying from Data,
# 'Copy' are special copy scripts (defined in copy_files.py) that move files from $DATA to the chroot
export OUTSIDE="$THIS_PROJECT"/outside
export BEFORE_COPY="$THIS_PROJECT"/before_copy
export COPY="$THIS_PROJECT"/copy
export STARTERS="$THIS_PROJECT"/start
export AFTER="$THIS_PROJECT"/after

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--permanent)
      permanent=""
      shift # past argument
      shift # past value
      ;;
    # VERY DANGEROUS! Applies changes to THIS COMPUTER, not a chroot!!!
    --production)
      export is_production=true
      export THIS_CHROOT="/"
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option <$1>"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done ; set -- "${POSITIONAL_ARGS[@]}"

if [ -f "$CONFIG" ] ; then
  . "$CONFIG"
fi

for action in "$@" ; do
  do_special "$action"
  do_automatic "$action"
done
if [ ! "$is_production" ] && [ ! "$NO_ENTER" ] && [ -d "$THIS_CHROOT" ] ; then
  systemd-nspawn $permanent -b -D "$THIS_CHROOT"
fi
