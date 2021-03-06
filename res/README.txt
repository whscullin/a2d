Apple II DeskTop
================

A2DeskTop.po is an 800k image containing the full application and
all accessories. It can be transferred to an 3.5" floppy using ADTPro.

A2DeskTop.1.po and A2DeskTop.2.po are 140k images containing different
parts of the application, and can be transferred to 5.25" floppies
using ADTPro.


Documentation
-------------

See https://a2desktop.com for more information.

Source code can be found at: https://github.com/a2stuff/a2d


Installation
------------

This is a ProDOS 8 application. It works best on a mass storage
device, or at least an 800k floppy. Running from 140k is possible
(without desk accessories) but is not recommended.

An Apple II DeskTop installation has the following structure on a mass
storage device:

* `A2.DESKTOP/` - any name is allowed, can be in any subdirectory
  * `DESKTOP.SYSTEM` - run this to launch DeskTop
  * `DESKTOP2` - application file
  * `DESK.ACC/` - contains Desk Accessories (DAs)
  * `PREVIEW/` - contains file preview handlers (special type of DAs)

A simplified program selector can be launched instead by moving
the `SELECTOR` file from the `OPTIONAL/` directory into the same
directory as `DESKTOP.SYSTEM`.
