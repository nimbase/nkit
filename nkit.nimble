# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Unified system APIs across multiple platforms"
license       = "MIT"
srcDir        = "src"
bin           = @["nkit"]
installDirs   = @["nkit"]
installExt    = @["nim"]
binDir        = "bin"

# Dependencies

requires "nim >= 2.2.10"
requires "kapsis >= 0.4.7"
requires "openparser >= 0.2.0"