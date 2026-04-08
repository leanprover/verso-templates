# Slides

This template creates a [`reveal.js`](https://revealjs.com) slide presentation using
[verso-slides](https://github.com/leanprover/verso-slides). It includes a title slide and a slide
that demonstrates Lean code with an info panel.

## Building

To build the slides, run:
```
$ lake exe generate-slides
```

The output is written to the `_slides/` directory. Run a local web server to view the presentation.

## More Features

See the [`verso-slides` demo file](https://github.com/leanprover/verso-slides/blob/main/Demo.lean) for
a comprehensive showcase of all available features, including:

* Treating sections of code as [`reveal.js` fragments](https://revealjs.com/fragments/)
* Fragment animations (block and inline)
* Speaker notes
* Custom slide backgrounds and transitions
* Vertical slides
* Code blocks in other languages using `reveal.js`'s built-in syntax highlighting
