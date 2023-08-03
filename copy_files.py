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
def copy_file(path1, path2):
  # shutil.copytree passes strings, which don't have parent
  if type(path2) == str:
    path2 = Path(path2)
  if not os.path.exists(path2.parent):
    os.makedirs(path2.parent)
  shutil.copy2(path1, path2)
  st = os.stat(path1)
  os.chown(path1, st.st_uid, st.st_gid)
  
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

# /gaga/a --> /googoo/b
def copy_files(source_root, target_root, filelist):
  for line in lines(filelist):
    try:
      a, b = line.split(' --> ')
      # UNIX ONLY
      b = b.lstrip('/')
      tru_a = source_root/a
      tru_b = target_root/b
      if os.path.isdir(tru_a):
        remove(tru_b)
        shutil.copytree(tru_a, tru_b, copy_function=copy_file)
      elif os.path.isfile(tru_a):
        copy_file(tru_a, tru_b)
      else:
        print(f"Couldn't copy <{tru_a}> because it doesn't exist!")
    except ValueError:
      print(f"<{line}> is not formatted correctly")
    except PermissionError:
      print(f"<{line}> got a permission error")
  
if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('source_root', type=str)
  parser.add_argument('target_root', type=str)
  parser.add_argument('filelist', type=str)
  args = parser.parse_args(sys.argv[1:])
  require([args.source_root, args.target_root], os.path.isdir)
  require([args.filelist], os.path.isfile)
  copy_files(Path(args.source_root), Path(args.target_root), args.filelist)
  
  