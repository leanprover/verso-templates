import VersoBlog
import Blog

open Verso Genre Blog Site Syntax

def blog : Site := site Blog.FrontPage /
  "about" Blog.About
  "blog" Blog.Posts with
    Blog.Posts.FirstPost

def main := blogMain .default blog
