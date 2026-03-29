import Std.Data.HashMap

open Std

-- ANCHOR: Expr
inductive Expr where
  | var : String → Expr
  | nat : Nat → Expr
  | plus : Expr → Expr → Expr
-- ANCHOR_END: Expr

-- ANCHOR: eval
def Expr.eval (ρ : HashMap String Nat) :
    Expr → Except String Nat
  | .var x =>
    if let some v := ρ[x]? then pure v
    else throw s!"{x} not found"
  | .nat n => pure n
  | .plus e1 e2 => do
    return (← e1.eval ρ) + (← e2.eval ρ)
-- ANCHOR_END: eval

-- ANCHOR: optimize
def Expr.optimize : Expr → Expr
  | .plus e1 e2 =>
    match e1.optimize, e2.optimize with
    | .nat n, .nat k => .nat (n + k)
    | .nat 0, e2' => e2'
    | e1', .nat 0 => e1'
    | e1', e2' => .plus e1' e2'
  | e => e
-- ANCHOR_END: optimize

-- ANCHOR: optimize_correct
theorem optimize_correct (e : Expr) :
    e.eval ρ = e.optimize.eval ρ := by
  -- ANCHOR: lemma
  have : HAdd.hAdd 0 = id := by grind
  -- ANCHOR_END: lemma
  -- ANCHOR: ind
  fun_induction Expr.optimize <;> simp [Expr.eval, *]
  -- ANCHOR_END: ind
-- ANCHOR_END: optimize_correct
