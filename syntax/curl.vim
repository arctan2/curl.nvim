if exists("b:current_syntax")
  finish
endif

syntax match curlSection /^#[A-Z]\+/
highlight curlSection ctermfg=Yellow guifg=#ffff00

let b:current_syntax = "curl"
