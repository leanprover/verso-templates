/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import VersoBlog
import Blog.Categories
open Verso Genre Blog

open Verso.Code.External

set_option verso.exampleProject "../blog-examples/4.22.0"
set_option verso.exampleModule "New"

#doc (Post) "Lean Got Better!" =>

%%%
authors := ["Alex"]
date := {year := 2025, month := 8, day := 14}
categories := [examples]
%%%

Lean has definitely improved in the last couple of years!
As I write this, Lean 4.22 is hot off the presses, so let's look at a few of the improvements since 4.0.
In Lean, I can define a type of expressions with variables:

```anchor Expr
inductive Expr where
  | var : String → Expr
  | nat : Nat → Expr
  | plus : Expr → Expr → Expr
```

Given values for the expression's variables, an evaluator assigns a value to the expression as a whole:
```anchor eval
def Expr.eval (ρ : HashMap String Nat) :
    Expr → Except String Nat
  | .var x =>
    if let some v := ρ[x]? then pure v
    else throw s!"{x} not found"
  | .nat n => pure n
  | .plus e1 e2 => do
    return (← e1.eval ρ) + (← e2.eval ρ)
```

Even before their variables have values, expressions can be optimized by performing rewrites such as $`e + 0 ↦ e`, $`0 + e ↦ e`, as well as pre-adding constants:
```anchor optimize
def Expr.optimize : Expr → Expr
  | .plus e1 e2 =>
    match e1.optimize, e2.optimize with
    | .nat n, .nat k => .nat (n + k)
    | .nat 0, e2' => e2'
    | e1', .nat 0 => e1'
    | e1', e2' => .plus e1' e2'
  | e => e
```

To prove this optimizer correct, we can use induction on its call graph.
```anchor optimize_correct
theorem optimize_correct (e : Expr) :
    e.eval ρ = e.optimize.eval ρ := by
  have : HAdd.hAdd 0 = id := by grind
  fun_induction Expr.optimize <;> simp [Expr.eval, *]
```
The first step is to establish a fact that will be needed in the $`0 + e ↦ e` case:
```anchor lemma
  have : HAdd.hAdd 0 = id := by grind
```
Having this in the context makes it available in the use of {anchorTerm ind}`simp [Expr.eval, *]` in the induction:
```anchor ind
  fun_induction Expr.optimize <;> simp [Expr.eval, *]
```
{anchorTerm ind}`fun_induction` creates five cases: one for each pattern in the {anchorTerm optimize}`match e1.optimize, e2.optimize`, and one for the fallback {anchorTerm optimize}`e => e`.
The simplifier takes care of all of them, using the lemma.

In older versions of Lean, this was more difficult!
The definition of expressions and the optimizer are the same, but the evaluator represents its environment as a list of pairs because {anchorName eval}`HashMap` was not yet available:
```anchor eval (module := Old) (project := "../blog-examples/4.0.0")
def Expr.eval (ρ : List (String × Nat)) :
    Expr → Except String Nat
  | .var x =>
    if let some v := ρ.lookup x then pure v
    else throw s!"{x} not found"
  | .nat n => pure n
  | .plus e1 e2 => do
    return (← e1.eval ρ) + (← e2.eval ρ)
```

Back then, the {anchorTerm ind}`fun_induction` tactic was not yet available, so the older proof is by induction on the structure of the expression being optimized:
```anchor correct (module := Old) (project := "../blog-examples/4.0.0")
theorem optimize_correct (e : Expr) :
    e.eval ρ = e.optimize.eval ρ := by
  induction e with
  | plus e1 e2 ih1 ih2 =>
    simp only [Expr.optimize]
    split <;> simp [Expr.eval, *]
  | var | nat =>
    simp [Expr.optimize]
```
This proof was written to be as similar as possible to the newer version.
The {anchorTerm correct (module := Old) (project := "../blog-examples/4.0.0")}`| var | nat =>` case matches the fallback case, and {anchorTerm correct (module := Old) (project := "../blog-examples/4.0.0")}`split` creates the other cases.
Nonetheless, the proof is noisier, and requires steps like unfolding {anchorName correct (module := Old) (project := "../blog-examples/4.0.0")}`Expr.optimize` prior to case-splitting.
Furthermore, because there was not nearly as much theory in the standard library back then, this proof also requires additional lemmas:
```anchor lemmas (module := Old) (project := "../blog-examples/4.0.0")
@[simp]
theorem Except.pure_bind (v : α) (f : α → Except ε β) :
    pure v >>= f = f v := by
  simp [bind, Except.bind, pure, Except.pure]

@[simp]
theorem Except.bind_pure_comp (e : Except ε α) :
    e >>= (pure ·) = e := by
  cases e <;> simp [bind, Except.bind, pure, Except.pure]
```

Even for tiny proofs like this, the progress is wonderful!
And newer versions are also full of quality-of-life improvements, like better error messages, suggestions in case of typos, and more.
I'm really looking forward to what comes next.
