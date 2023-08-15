import os
import sys
from pathlib import Path
import argparse
import shutil

# Expects a list of tuples: constant, some boolean function required of the constant
def require(list_, func):
  for thing in list_:
    if not func(thing):
      sys.exit(f"Requirement error: <{thing}> does not match <{func.__name__}>.")
  return True

# Add more if necessary
def copy_file(path1, path2, owner_id=None, group_id=None, perms=None):
  # shutil.copytree passes strings, which don't have parent
  if type(path2) == str:
    path2 = Path(path2)
  # If this is a directory, we are a child file.
  if path2.is_dir():
    path2 = path2/path1.name
  # shutil.copy2 will follow symlinks when copying, even if follow_symlinks is False.
  # To replace the file, we remove the symlink ourself.
  if path2.is_symlink():
    path2.unlink()
  shutil.copy2(path1, path2, follow_symlinks=False)
  if perms != None:
    os.chmod(path2, perms)
  st = os.stat(path1)
  os.chown(path2, st.st_uid if owner_id == None else owner_id, st.st_gid if group_id == None else group_id)

def pretend_to_copy_file(path1, path2, owner_id=None, group_id=None, perms=None):
  # shutil.copytree passes strings, which don't have parent
  if type(path2) == str:
    path2 = Path(path2)
  # If this is a directory, we are a child file.
  if path2.is_dir():
    path2 = path2/path1.name
  if path2.exists():
    path2.unlink()
  os.link(path1, path2)
  if perms != None:
    os.chmod(path2, perms)
  st = os.stat(path1)
  os.chown(path2, st.st_uid if owner_id == None else owner_id, st.st_gid if group_id == None else group_id)


def recursive_folder_fix(path, owner_id=None, group_id=None, perms=None):
  next_dirs = [path/d for d in os.listdir(path) if os.path.isdir(path/d)]
  if perms != None:
    os.chmod(path, perms)
  st = os.stat(path)
  os.chown(path, st.st_uid if owner_id == None else owner_id, st.st_gid if group_id == None else group_id)
  for dir_ in next_dirs:
    recursive_folder_fix(dir_, owner_id=owner_id, group_id=group_id, perms=perms)
  
def lines(filename):
  with open(filename) as f:
    for line in f:
      lstrip = line.rstrip()
      if len(lstrip) != 0 and lstrip[0] != '#':
        yield lstrip

def remove(file_):
  if os.path.isdir(file_):
    shutil.rmtree(file_)
  elif os.path.isfile(file_):
    os.remove(file_)
    
def translate_usrgrp(id_or_name, id_dict):
  if id_or_name.isdigit():
    return int(id_or_name)
  elif id_or_name in id_dict:
    return id_dict[id_or_name]
  else:
    print(f"Invalid id or group {id_or_name}")
    return None

# /gaga/a --> /googoo/b
def copy_files(source_root, target_root, filelist, users, groups):
  cp_func = copy_file
  for line in lines(filelist):
    owner_id = None
    group_id = None
    perms = None
    folder_perms = None
    parts = line.split(' // ')
    for addition in parts[1:]:
      if addition.startswith("owned: "):
        # Interpret: 'owned: user:group' ; restraints user:group may be missing or could be an integer
        usrgrp = addition[len("owned: "):].strip().split(':')
        owner_id = translate_usrgrp(usrgrp[0], users)
        group_id = translate_usrgrp(usrgrp[1], groups) if len(usrgrp) > 1 else None
      elif addition.startswith("perms: "):
        # Interpret: 'owned: user:group' ; restraints user:group may be missing or could be an integer
        try:
          perms = int(addition[len("perms: "):].strip(), 8)
        except:
          pass
      elif addition.startswith("folder-perms: "):
        # Interpret: 'owned: user:group' ; restraints user:group may be missing or could be an integer
        try:
          folder_perms = int(addition[len("folder-perms: "):].strip(), 8)
        except:
          pass
      elif addition.startswith("linked"):
        cp_func = pretend_to_copy_file
    try:
      a, b = parts[0].split(' --> ')
      # UNIX ONLY
      b = b.lstrip('/')
      tru_a = source_root/a
      tru_b = target_root/b
      if os.path.isdir(tru_a):
        remove(tru_b)
        shutil.copytree(tru_a, tru_b, symlinks=True, copy_function=lambda a,b: cp_func(a, b, owner_id=owner_id, group_id=group_id, perms=perms))
        recursive_folder_fix(tru_b, owner_id=owner_id, group_id=group_id, perms=folder_perms)
      elif os.path.isfile(tru_a):
        cp_func(tru_a, tru_b, owner_id=owner_id, group_id=group_id, perms=perms)
      else:
        print(f"Couldn't copy <{tru_a}> because it doesn't exist!")
    except ValueError:
      print(f"<{line}> is not formatted correctly")
    except PermissionError:
      print(f"<{line}> got a permission error")
    except FileExistsError:
      print(f"<{line}> got a file exists error. That's weird, thought I fixed that.")
    except FileNotFoundError:
      print(f"<{line}> got a file not found error (either the file or the containing folder in the chroot do not exist)")
      
def parse_users(passwd_file):
  users = {}
  for line in lines(passwd_file):
    split = line.split(':')
    # groups[group name] = user id
    users[split[0]] = int(split[2])
  return users

def parse_groups(groups_file):
  groups = {}
  for line in lines(groups_file):
    split = line.split(':')
    # groups[group name] = group id
    groups[split[0]] = int(split[2])
  return groups
  
if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('source_root', type=str)
  parser.add_argument('target_root', type=str)
  parser.add_argument('filelist', type=str)
  parser.add_argument('passwd_file', type=str)
  parser.add_argument('groups_file', type=str)
  args = parser.parse_args(sys.argv[1:])
  require([args.source_root, args.target_root], os.path.isdir)
  require([args.filelist], os.path.isfile)
  copy_files(Path(args.source_root), Path(args.target_root), args.filelist, parse_users(args.passwd_file), parse_groups(args.groups_file))
