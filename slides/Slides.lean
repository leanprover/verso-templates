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
[`verso-slides`](https://github.com/leanprover/verso-slides).

# Lean Code

Here is a Lean code block:

```lean
def fib : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => fib (n + 1) + fib n
```

```lean
#eval fib 10
```

The function {lean}`fib` computes Fibonacci numbers.

# Thank You

:::fragment
Questions?
:::
