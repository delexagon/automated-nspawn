sav_dir="$HOME/saved_files"
log_file="$sav_dir/saved.txt"
notes_file="$sav_dir/notes.sh"
sav_editor=nano

# sudo_if_necessary <1/2nd operand> <read/read+write> <command> <1> <2>
sudo_if_necessary() {
  # Either: The file doesn't exist and we have write permissions to its folder,
  #         or we have read and write permissions to the file.
  if [ "$1" = '1' ]; then
    check_file="$4"
  else
    check_file="$5"
  fi
  if [ "$2" = "read" ]; then
    [[ -r "$check_file" ]]
  else
    [[ ! -e "$check_file" && -w $(dirname "$check_file") ]] || [[ -r "$check_file" && -w "$check_file" ]]
  fi
  if [ "$?" -eq 0 ]; then
    "$3" "${@:4}"
  else
    echo "You are missing permissions for $3 ${@:4}"
    sudo "$3" "${@:4}"
  fi
}

# Note a changing command you've run; saves the command to a file
# The command should be enclosed in 's
n() {
  eval "$1"
  echo "$1" >> "$notes_file"
}

nrm() {
  sed -i '$d' "$notes_file"
}

savefile() {
  base=$(basename "$1")
  savefile_sav_file="$base.$(TZ=":US/Eastern" date --rfc-3339=seconds | sed 's/[ :-]/_/g')"
  savefile_sav_path="$sav_dir/$savefile_sav_file"
  
  sudo_if_necessary 1 read cp "$1" "$savefile_sav_path"
  if [ "$?" = 0 ]; then
    full=$(realpath -s "$1")
    echo "<$savefile_sav_file> originally <$full>" >> "$log_file"
    echo "Saved <$full> as <$savefile_sav_file>"
  fi
}

savemv() {
  base=$(basename "$1")
  savemv_sav_file="$base.$(TZ=":US/Eastern" date --rfc-3339=seconds | sed 's/[ :-]/_/g')"
  savemv_sav_path="$sav_dir/$savemv_sav_file"
  sudo_if_necessary 1 read+write mv "$1" "$savemv_sav_path"
  if [ "$?" = 0 ]; then
    full=$(realpath -s "$1")
    echo "<$savemv_sav_file> originally moved as <$full>" >> "$log_file"
    echo "Moved <$full> to <$savemv_sav_file>"
  fi
}

mod() {
  if [ -f "$1" ]; then
    savefile "$1"
    sudo_if_necessary 1 read+write "$sav_editor" "$1"
    # If diff returns 0; i.e. they are not different
    if diff "$1" "$savefile_sav_path"; then
      rm "$savefile_sav_path"
      echo "Removed $savefile_sav_path; no changes"
      sed -i '$d' "$log_file"
    fi
  else
    echo "<$1> not file"
  fi
}

srm() {
  for arg in "$@"; do
    if [ -e "$arg" ]; then
      savemv "$arg"
    else
      echo "<$arg> not file or directory"
    fi
  done
}

restore() {
  for arg in "$@"; do
    sav_path="$sav_dir/$arg"
    original_path=$(grep "$arg" "$log_file" | sed "s/^<.*> .* <\(.*\)>$/\1/g")
    # Restoring directories removes the save; it is expected that directories will be managed more carefully
    if [ -f "$original_path" ]; then
      latest_sav=$(grep "$original_path" "$log_file" | tail -1 | sed "s/^<\(.*\)> .* <.*>$/\1/g")
      latest_sav_path="$sav_dir/$latest_sav"
      # If diff returns 1; i.e. they are different
      sudo_if_necessary 2 read diff "$latest_sav_path" "$original_path"
      if [ $? = 1 ]; then
        savefile "$original_path"
      fi
      sudo_if_necessary 2 read+write cp "$sav_path" "$original_path"
    elif [ -d "$original_path" ]; then
      savemv "$original_path"
      sudo_if_necessary 2 read+write mv "$sav_path" "$original_path"
    else
      if [ -f "$sav_path" ]; then
        sudo_if_necessary 2 read+write cp "$sav_path" "$original_path"
      elif [ -d "$sav_path" ]; then
        sudo_if_necessary 2 read+write mv "$sav_path" "$original_path"
      else
        echo "<$sav_path> not file or directory"
      fi
    fi
  done
}
