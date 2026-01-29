This is a demonstration of a textbook built in Verso's manual genre.

To build it, run:
```
$ lake exe textbook
```

This textbook is written in the `Manual` genre. It uses the same
version of Lean for the example code as it does for Verso itself;
please see [the package description example](../package-docs) for an
example in which the Lean code is external to the document and written
in a different version of Lean.

# Code Samples

Additionally, this example demonstrates a non-trivial extension to the
manual genre: extraction of Lean modules from the inline examples. This
extension uses [a custom `savedLean` code block](TextbookTemplate/Meta/Lean.lean)
to indicate that an example or exercise should be saved. At elaboration time,
a custom block element saves the original filename and the contents of the
code block. Then, in [`TextbookTemplateMain.lean`](TextbookTemplateMain.lean), the
custom build step `buildExercises` traverses the entire book prior to HTML
generation, collecting the exercise blocks. The collected blocks are assembled
into files and written to the `example-code` subdirectory of the output.


