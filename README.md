# dim-jump

*To Use*:

when over an identifier, use the `:DimJumpPos` command


When the command is used, the variable `b:preferred_searcher`, if not already set, becomes a string which is one of ( in order preferring:  ) `git-grep, ag, rg, grep`. The first time you ever use the command the dependency with pattern definitions is curl'd and parsed into a json-ish file in the plugin directory. that's all really, just `:DimJumpPos`.


[dumb-jump.el](https://github.com/jacktasia/dumb-jump)
