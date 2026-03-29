import VersoManual

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

#doc (Manual) "Introduction" =>

Lean is a programming language and theorem prover. Here is a simple function that doubles a natural number:

```lean
def double (n : Nat) : Nat := n + n
```
