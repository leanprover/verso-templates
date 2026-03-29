/-
Copyright (c) 2023-2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import VersoBlog

open Verso.Genre.Blog.Post

namespace Blog

def examples : Category where
  name := "Examples of Verso usage"
  slug := "examples"

def other : Category where
  name := "Other content"
  slug := "other"
