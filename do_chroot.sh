#!/bin/bash

if [ ! "$EUID" = "0" ] ; then
  echo "Not root"
  exit 1
fi

do_automatic() {
  if [ -f "$OUTSIDE/$1".sh ] ; then
    bash "$OUTSIDE/$1".sh
  fi
  if [ -f "$COPY/$1".cp ] ; then
    python3 copy_files.py "$DATA" "$THIS_CHROOT" "$COPY/$1".cp
  fi
  if [ -f "$THIS_PROJECT/start/$1" ] ; then
    cp "$THIS_PROJECT/start/$1" "$THIS_CHROOT/root/$1"
    chmod 500 "$THIS_CHROOT/root/$1"
    systemd-nspawn -D "$THIS_CHROOT" -a "/root/$1"
  fi
}

if [ ! -e 'chroots' ] ; then
  mkdir chroots
fi

# Expectations: do_chroot.sh init name_of_chroot <project_name> <-b build>
# Expectations: do_chroot.sh load name_of_chroot 
action="$1"
CHROOT_NAME="$2"
if ! [[ "$CHROOT_NAME" =~ ^[a-zA-Z0-9_-]*$ ]] ; then
  echo "Invalid chroot name"
  exit 1
fi
if ! [[ "$action" =~ ^[a-zA-Z0-9_-]*$ ]] ; then
  echo "Invalid action name"
  exit 1
fi

shift 2
export THIS_CHROOT=$(realpath chroots/"$CHROOT_NAME")
export CONFIG_FILE=$(realpath config.txt)

# ARGUMENTS
POSITIONAL_ARGS=()
if [ "$action" = init ] ; then 
  while [[ $# -gt 0 ]]; do
    case $1 in
      -b|--build)
        BUILD="$2"
        shift # past argument
        shift # past value
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
  
  export BUILD=${BUILD:-jammy}
  
  export PROJECT_NAME=${1:-template}
  
elif [ "$action" = remove ] ; then
  rm -rf "$THIS_CHROOT"
  line_number=$(awk -v name="$CHROOT_NAME" '$1 ~ name { print FNR ; exit }' "$CONFIG_FILE")
  sed -i "$line_number"d "$CONFIG_FILE"
else
  if ! [ -d "$THIS_CHROOT" ] ; then
    echo "$THIS_CHROOT does not exist"
    exit 1
  fi
  # Turn on impermanence by default
  permanent="-x"
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--permanent)
        permanent=""
        shift # past argument
        shift # past value
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
  
  export PROJECT_NAME=$(awk -v name="$CHROOT_NAME" '$1 ~ name { print $2 ; exit }' "$CONFIG_FILE")
fi

# get line number (to remove config line): 

export THIS_PROJECT=$(realpath projects/"$PROJECT_NAME")
export STARTERS="$THIS_PROJECT"/start
export OUTSIDE="$THIS_PROJECT"/outside
export DATA="$THIS_PROJECT"/data
export COPY="$THIS_PROJECT"/copy
  
if [ "$action" = init ] ; then
  if ! python3 make_chroot.py "chroots" "$CHROOT_NAME" "$BUILD" ; then
    echo "Making chroot failed"
    exit 1
  fi
  
  cp "$THIS_PROJECT/start/"* "$THIS_CHROOT/root"
  echo "$CHROOT_NAME $PROJECT_NAME" >> "$CONFIG_FILE"

  do_automatic "$action"

else
  do_automatic "$action"
  systemd-nspawn $permanent -b -D "$THIS_CHROOT"
fi
