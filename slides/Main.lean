import VersoSlides
import Slides

open VersoSlides

def main (args : List String) : IO UInt32 :=
  slidesMain (doc := %doc Slides) (args := args)
