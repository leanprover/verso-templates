import Lake

open Lake DSL

require subverso from git "https://github.com/leanprover/subverso.git"@"no-modules/52b9dfbd2658408e37ae6e8b72601ddeaaa25a0c"



package examples where
  buildDir := ".lake/build"
  packagesDir := ".lake/packages"

lean_lib Old
