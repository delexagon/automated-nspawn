import os
import sys
from pathlib import Path
import argparse
import subprocess

def requirements(*args):
  for i, b in enumerate(args):
    if not b:
      sys.exit(f"Requirement {i} failed")

# Expects a list of tuples: constant, some boolean function required of the constant
def require(list_, func):
  for thing in list_:
    if not func(thing):
      sys.exit(f"Argument error: <{thing}> does not match <{func.__name__}>.")
  return 0

def is_root():
  return os.geteuid() == 0

def is_direct_subdir(root_path, sub_path):
  return root_path == (sub_path/'..').resolve()

def debootstrap(path, build='stable'):
  if build == None:
    build = 'stable'
  subprocess.run(["debootstrap", "--variant=buildd", build, path])

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('chroots_dir', type=str)
  parser.add_argument('chroot_name', type=str)
  parser.add_argument('build', type=str)
  args = parser.parse_args(sys.argv[1:])
  root = Path(args.chroots_dir).resolve()
  full_path = root/args.chroot_name
  requirements(
    is_root(),
    os.path.isdir(root),
    is_direct_subdir(root, full_path),
    not os.path.exists(full_path)
  )
  os.mkdir(full_path)
  debootstrap(full_path, build=args.build)
