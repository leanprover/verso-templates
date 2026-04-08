import VersoSlides

open VersoSlides

#doc (Slides) "My Presentation" =>
%%%
theme := "black"
slideNumber := true
transition := "slide"
%%%

# Welcome

This is a presentation built with
[VersoSlides](https://github.com/leanprover/verso-slides).

# Lean Code

Here is an elaborated Lean code block:

```lean
def fibonacci : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => fibonacci (n + 1) + fibonacci n
```

```lean
#eval fibonacci 10
```

The function {lean}`fibonacci` computes Fibonacci numbers.

# Thank You

:::fragment
Questions?
:::
