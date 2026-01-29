import Lake

open Lake DSL

require subverso from git "https://github.com/leanprover/subverso.git"@"no-modules/1e55697c44a646f8a22e2a91878efc4496aa5743"



package examples where
  buildDir := ".lake/build"
  packagesDir := ".lake/packages"

lean_lib Old
