# A Basic Verso Book

A one-page note built with Verso's Manual genre.
The example in `Note.lean` is one of the [Verso examples on live.lean-lang.org](https://live.lean-lang.org/#url=https%3A%2F%2Flive.lean-lang.org%2Fapi%2Fexample%2Fverso-demo%2FVersoDemo%2FIntegralApprox.lean&project=verso-demo),
and replacing `Note.lean` with any Verso project example on live.lean-lang.org should work.

## Previewing HTML

Build with:

```
lake build
lake exe generate-doc
```

The generated site will be in `_out/html-single/`. 

With Python, you can preview it with

```
python3 -m http.server -d _out/html-single
```