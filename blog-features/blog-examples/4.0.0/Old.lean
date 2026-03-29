-- ANCHOR: Expr
inductive Expr where
  | var : String → Expr
  | nat : Nat → Expr
  | plus : Expr → Expr → Expr
-- ANCHOR_END: Expr

-- ANCHOR: Optimize
def Expr.optimize : Expr → Expr
  | .plus e1 e2 =>
    match e1.optimize, e2.optimize with
    | .nat n, .nat k => .nat (n + k)
    | .nat 0, e2' => e2'
    | e1', .nat 0 => e1'
    | e1', e2' => .plus e1' e2'
  | e => e
-- ANCHOR_END: Optimize

-- ANCHOR: eval
def Expr.eval (ρ : List (String × Nat)) :
    Expr → Except String Nat
  | .var x =>
    if let some v := ρ.lookup x then pure v
    else throw s!"{x} not found"
  | .nat n => pure n
  | .plus e1 e2 => do
    return (← e1.eval ρ) + (← e2.eval ρ)
-- ANCHOR_END: eval

-- ANCHOR: lemmas
@[simp]
theorem Except.pure_bind (v : α) (f : α → Except ε β) :
    pure v >>= f = f v := by
  simp [bind, Except.bind, pure, Except.pure]

@[simp]
theorem Except.bind_pure_comp (e : Except ε α) :
    e >>= (pure ·) = e := by
  cases e <;> simp [bind, Except.bind, pure, Except.pure]
-- ANCHOR_END: lemmas

-- ANCHOR: correct
theorem optimize_correct (e : Expr) :
    e.eval ρ = e.optimize.eval ρ := by
  induction e with
  | plus e1 e2 ih1 ih2 =>
    simp only [Expr.optimize]
    split <;> simp [Expr.eval, *]
  | var | nat =>
    simp [Expr.optimize]
-- ANCHOR_END: correct
