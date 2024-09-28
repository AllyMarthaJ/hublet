# Package

version       = "0.1.0"
author        = "AllyMarthaJ"
description   = "Automation hub for Ally"
license       = "GPL-2.0-or-later"
srcDir        = "src"
binDir        = "bin"
bin           = @["hublet", "tests/test"]


# Dependencies

requires "nim >= 2.0.8"
requires "unittest2 >= 0.2.2"