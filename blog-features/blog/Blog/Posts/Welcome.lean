/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import VersoBlog
import Blog.Categories
open Verso Genre Blog

#doc (Post) "Writing Technical Posts in Lean" =>

%%%
authors := ["Alex"]
date := {year := 2025, month := 7, day := 12}
categories := [examples, other]
%%%

```leanInit welcome
```


I've been thinking about starting a technical blog for a while, and recently decided to try Verso—a documentation tool that lets you write in Lean 4. The appeal is being able to mix explanations with actual executable code and verified proofs rather than relying on screenshots or hand-wavy arguments. Since Lean understands the code directly, you get accurate syntax highlighting, identifiers automatically link to the Lean reference manual, and you can hover over functions to see their documentation and type signatures.

Here are a couple of examples to show what this looks like in practice.

# A Simple Program: Computing Fibonacci Numbers

Here's a straightforward function that computes Fibonacci numbers:

```lean welcome
def fib : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => fib n + fib (n + 1)
```

As expected, it maps natural numbers to natural numbers:
```lean welcome (name := checkFib)
#check fib
```
```leanOutput checkFib
fib : Nat → Nat
```

The answers are as expected:
```lean welcome (name := evalFib10)
#eval fib 10
```
```leanOutput evalFib10
55
```

```lean welcome (name := evalFib15)
#eval fib 15
```
```leanOutput evalFib15
610
```

The `#eval` commands show the actual computed results. This naive recursive implementation isn't efficient for large numbers, but it clearly demonstrates the mathematical definition. When you see this code, you know it actually runs exactly as written—there's no risk of typos or inconsistencies between the explanation and implementation.

# Proofs Don't Fib

Here are a couple of proofs that demonstrate Lean's verification capabilities using our Fibonacci function. First off, the Fibonacci sequence is non-decreasing. That is, $`F_{n} \le F_{n + 1}`:

```lean welcome
theorem fib_nondec : fib n ≤ fib (n + 1) := by
  induction n <;> simp [fib]
```

Furthermore, the sequence is strictly increasing after the first two elements. The first step is to show that for all positive $`n`, $`F_n` is positive:
```lean welcome
@[grind]
theorem fib_pos : n > 0 → fib n > 0 := by
  induction n with
  | zero => simp [fib]
  | succ n' ih =>
    simp
    cases n' <;> grind [fib]
```
Now, `grind` can use the lemma to show that `fib` is strictly increasing:
```lean welcome
theorem fib_gt_1_inc : fib (n + 2) < fib (n + 3) := by
  induction n <;> grind [fib]
```

Additionally, every third element of the sequence is even.
If a number $`n` is even, then there exists some $`k` such that $`n = 3k`; the proof is by induction on $`k`.
```lean welcome
theorem fib_third_even : 3 ∣ n → 2 ∣ fib n := by
  intro ⟨k, hk⟩
  rw [hk]
  clear n hk
  induction k <;> grind [fib]
```

# Moving Forward

Having executable code and verified proofs directly in blog posts eliminates the usual gap between explanation and implementation. The interactive features—like being able to hover over function names to see their types and documentation—make the reading experience more informative than “plain” code blocks. Furthermore, tactic proofs are difficult to read without intermediate proof states, so Verso makes these visible.

For more advanced users, Verso itself can be extended in Lean, which opens up interesting possibilities for custom blog functionality. I'm planning to explore some data structure implementations and more mathematical concepts in future posts.
