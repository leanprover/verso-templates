/-
Copyright (c) 2023-2024 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import VersoBlog
import Blog.Categories
open Verso Genre Blog

#doc (Post) "Making Fibonacci Fast (And Proving It's Correct)" =>

%%%
authors := ["Alex"]
date := {year := 2025, month := 7, day := 19}
categories := [examples]
%%%

```leanInit welcome
```

In my last post, I showed off a simple recursive Fibonacci implementation. While it clearly expresses the mathematical definition, it has a serious performance problem that becomes obvious pretty quickly.

# The Problem with Naive Recursion

Let's look at our original definition again:

```lean welcome
def fib : Nat → Nat
  | 0 => 0
  | 1 => 1
  | n + 2 => fib n + fib (n + 1)
```
Evaluating `fib 10` is plenty fast:
```lean welcome (name := fib10)
#eval fib 10
```
```leanOutput fib10
55
```

Evaluating `fib 30`, however, takes a noticable pause:
```lean welcome (name := fib30)
#eval fib 30
```
```leanOutput fib30
832040
```
Evaluating `fib 40` would take too long.

The issue is that this definition computes the same Fibonacci numbers over and over again. To calculate `fib 5`, we need `fib 3` and `fib 4`. But to calculate `fib 4`, we need `fib 2` and `fib 3` again. The amount of redundant computation grows exponentially.

# An Iterative Solution

We can solve this with an iterative approach that computes each Fibonacci number exactly once:

```lean welcome
def fibIter (n : Nat) : Nat := loop n (0, 1)
where
  loop
    | 0, (i, _) => i
    | k + 1, (i, j) => loop k (j, i + j)
```
This version works by maintaining a pair `(i, j)` representing consecutive Fibonacci numbers and updating them as we count down from n to 0. The computation is linear in n rather than exponential.

The result for `10` is computed very quickly:
```lean welcome (name := fibIter10)
#eval fibIter 10
```
```leanOutput fibIter10
55
```

So is the result for `30`:
```lean welcome (name := fibIter30)
#eval fibIter 30
```
```leanOutput fibIter30
832040
```

And even the result for `100`:
```lean welcome (name := fibIter100)
#eval fibIter 100
```
```leanOutput fibIter100
354224848179261915075
```




## Proving They're Equivalent

Of course, we want to be absolutely sure that our optimization didn't change the mathematical meaning. Here's where Lean really shines—we can prove that both implementations compute the same function.
The first step is to show the correctness of the inner loop.

This statement is a bit tricky.
It uses a loop invariant: at each step, where the Fibonacci number being computed is `n - k`, the pair contains the correct results.
The premise that `k ≤ n` is needed to ensure that `n - k` denotes a sensible index into the sequence.
The proof uses the `fun_induction` tactic to reason based on the call graph of `fibIter.loop`, and `grind` to dispatch all the tedious details.

```lean welcome
def fibIterloop_eq_fib :
    k ≤ n →
    i = fib (n - k) →
    j = fib (n - k + 1) →
    fibIter.loop k (i,  j) = fib n := by
  intros k_le_n  hi hj
  generalize hp : (i, j) = p
  fun_induction fibIter.loop generalizing i j
  next => grind
  next ih =>
    apply ih ?_ rfl rfl <;> grind [fib]
```

With this lemma, we can special-case the base cases of `fib` to prove the entire statement:
```lean welcome
def fibIter_eq_fib : fibIter = fib := by
  funext n
  unfold fibIter
  match n with
  | 0 | 1 =>
    grind [fib, fibIter.loop]
  | n' + 2 =>
    apply fibIterloop_eq_fib <;> grind [fib]
```

## Why This Matters

Having both a clear mathematical specification (`fib`) and an efficient implementation (`fibIter`), along with a machine-verified proof that they're equivalent, gives us the best of both worlds. We can reason about the mathematical properties using the simple recursive definition, while actually computing results with the fast iterative version.

This equivalence proof also means that all the properties I proved about `fib` in my last post—like the fact that every third Fibonacci number is even—automatically apply to `fibIter` as well. Lean can use the `fibIter_eq_fib` proof to rewrite any statement about `fibIter` into one about `fib`, letting us leverage all our previous mathematical work.
