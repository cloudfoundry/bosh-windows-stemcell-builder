### Instructions for building pigz.exe

#### Requirements:
  1. A Windows machine
  1. mingw-w64 (use the [installer](https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/installer/))
  1. Git Bash or Mingw for a 'bash like' terminal

#### Installation:
  1. From a Git Bash or Mingw terminal, clone: https://github.com/madler/pigz
  1. CD into pigz `cd pigz`
  1. Checkout latest release
  1. Change the first line of the Makefile (CC=cc => CC=gcc)
    * You can also delete the line declaring CC and run make with `CC=gcc mingw32-make.exe`
  1. Run `mingw32-make.exe` this will create pigz.exe and unpigz.exe in the current directory
  1. Done: pigz.exe and unpigz.exe can now be used
