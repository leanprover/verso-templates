import Lake

open Lake DSL

require subverso from git "https://github.com/leanprover/subverso.git"@"no-modules/1d663ae67d8088111bb37c3c526fe2d43e4df01c"



package examples where
  buildDir := ".lake/build"
  packagesDir := ".lake/packages"

lean_lib Old
