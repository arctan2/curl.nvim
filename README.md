# About

It's the most basic curl frontend.

# Usage

|command|action|
|-------|------|
|`:Curl`|try parsing and running the request under the cursor|
|`:CurlScratch`|open new scratch buffer. Note: you need to have [scratch.nvim](https://github.com/arctan2/scratch.nvim) plugin installed|

# Syntax

It has a very simple syntax

```
#REQ
<method> <host>
<header>

#<section-name>
<section-content>

<body-optional>

#RES <- optional
<the curl response will come here after running :Curl>

#END
```

## Note:
- The section content is a single paragraph and separate new line is considered as end of section.
- The body should always come after all the other section but before `#RES` or `#END`
- `#RES` should always be before `#END` and after all the other things.


