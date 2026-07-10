# Shim: child shells inherit ZDOTDIR and read $ZDOTDIR/.zshenv instead of
# ~/.zshenv, so forward to the real zshenv that lives next to this file.
source "${${(%):-%N}:A:h}/zshenv"
