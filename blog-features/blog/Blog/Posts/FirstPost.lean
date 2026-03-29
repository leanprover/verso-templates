/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import VersoBlog
import Blog.Categories
open Verso Genre Blog

#doc (Post) "Starting This Blog" =>

%%%
authors := ["Alex"]
date := {year := 2025, month := 7, day := 5}
categories := [examples, other]
%%%


I've been meaning to start writing about technical topics for a while, but kept putting it off. The usual blogging platforms never felt quite right for the kind of content I wanted to create—mixing code examples with mathematical reasoning in a way that actually works.

Over the past year, I've been learning about formal methods and theorem proving, partly out of curiosity and partly because I think these techniques could be useful for writing more reliable software.

This blog is going to document that learning process. I'm planning to explore how formal verification applies to everyday programming problems, work through some algorithm implementations with correctness proofs, and generally figure out how to bring more mathematical rigor to software development.

I'm not expecting to solve any deep theoretical problems here—this is more about learning in public and seeing how far I can push the practical applications of these ideas.

The posts will include working Lean code that you can actually run, along with proofs that you can trust are correct. If you're also interested in the intersection of mathematics and programming, hopefully you'll find something useful here.

I'm writing the blog itself in Lean, using Verso. This means I can include executable code and formal proofs directly in my posts, with everything verified by Lean's type system. No more worrying about whether code examples actually compile or whether informal mathematical arguments have gaps. This blog is also an exercise in learning Verso!
