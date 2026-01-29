/-
Copyright (c) 2024-2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import Std.Data.HashMap
import VersoManual
import TextbookTemplate

open Verso Doc
open Verso.Genre Manual

open Std (HashMap)

open TextbookTemplate


-- Computes the path of this very `main`, to ensure that examples get names relative to it
open Lean Elab Term Command in
#eval show CommandElabM Unit from do
  let here := (← liftTermElabM (readThe Lean.Core.Context)).fileName
  elabCommand (← `(private def $(mkIdent `mainFileName) : System.FilePath := $(quote here)))

/--
Extract the marked exercises and example code.
-/
partial def buildExercises (mode : Mode) (logError : String → IO Unit) (cfg : Config) (_state : TraverseState) (text : Part Manual) : IO Unit := do
  let .multi := mode
    | pure ()
  let code := (← part text |>.run {}).snd
  let dest := cfg.destination / "example-code"
  let some mainDir := mainFileName.parent
    | throw <| IO.userError "Can't find directory of `TextbookTemplateMain.lean`"

  IO.FS.createDirAll <| dest
  for ⟨fn, f⟩ in code do
    -- Make sure the path is relative to that of this one
    if let some fn' := fn.dropPrefix? mainDir.toString then
      let fn' := (fn'.dropWhile (· ∈ System.FilePath.pathSeparators)).copy
      let fn := dest / fn'
      fn.parent.forM IO.FS.createDirAll
      if (← fn.pathExists) then IO.FS.removeFile fn
      IO.FS.writeFile fn f
    else
      logError s!"Couldn't save example code. The path '{fn}' is not underneath '{mainDir}'."

where
  part : Part Manual → StateT (HashMap String String) IO Unit
    | .mk _ _ _ intro subParts => do
      for b in intro do block b
      for p in subParts do part p
  block : Block Manual → StateT (HashMap String String) IO Unit
    | .other which contents => do
      if which.name == ``Block.savedLean then
        let .arr #[.str fn, .str code] := which.data
          | logError s!"Failed to deserialize saved Lean data {which.data}"
        modify fun saved =>
          saved.alter fn fun prior =>
            let prior := prior.getD ""
            some (prior ++ code ++ "\n")

      if which.name == ``Block.savedImport then
        let .arr #[.str fn, .str code] := which.data
          | logError s!"Failed to deserialize saved Lean import data {which.data}"
        modify fun saved =>
          saved.alter fn fun prior =>
          let prior := prior.getD ""
          some (code.trimAsciiEnd.copy ++ "\n" ++ prior)

      for b in contents do block b
    | .concat bs | .blockquote bs =>
      for b in bs do block b
    | .ol _ lis | .ul lis =>
      for li in lis do
        for b in li.contents do block b
    | .dl dis =>
      for di in dis do
        for b in di.desc do block b
    | .para .. | .code .. => pure ()


def config : RenderConfig where
  emitTeX := false
  emitHtmlSingle := .no
  emitHtmlMulti := .immediately
  htmlDepth := 2

def main := manualMain (%doc TextbookTemplate) (extraSteps := [buildExercises]) (config := config)
