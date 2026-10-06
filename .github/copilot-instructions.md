losty is a web framework written in lauzy. See README.md if you haven't.

See lauzy/README.md for the syntax of lauzy if you are not familiar.
Dont trip:
- For recursive function, use let keyword: `let fn = \... -> fn()`
- `[[` and `]]` become one or more backticks. So the syntax of long comment starts with 2 dash and one or more backticks --` ... till end of the *matching* backtick count. And the uncomment trick is:
```
--`
print(10)         -- comment intended
---`              -- ** use 3 hyphens at ending **


---`              -- ** now add one hyphen at beginning to uncomment **
print(10)         --> now prints 10
---`
```



Only modify lau/*.lau files (tab indented), which can be transpiled to losty/*.lua (space indented) with make.bat.


bin/ folder is for new web application scaffold, which uses files in bin/new/ as template.

Provide only the raw code fix with brief introductory or concluding summary. Neither transpile nor run Test::Nginx. I can do so manually.

Always ask for clarifications on any doubts instead of guessing. Tell if you dont know.
