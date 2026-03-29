import Lake

open Lake DSL

require subverso from git "https://github.com/leanprover/subverso.git"@"no-modules/4539e605ff834c35ecc0bcd0b7daec69163fd9f0"



package examples where
  buildDir := ".lake/build"
  packagesDir := ".lake/packages"

lean_lib Old
