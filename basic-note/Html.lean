import VersoManual
import Note

open Verso.Genre Manual

def main := manualMain (%doc Note) (options := ["--with-html-single", "--without-html-multi"])
