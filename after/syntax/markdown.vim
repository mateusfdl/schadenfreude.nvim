syntax match aiResponseStart /^@AI :BEGIN$/ contained conceal cchar=󱙺
syntax match aiResponseEnd /^@AI :FINISH$/ contained conceal
syntax region aiResponse start=/^@AI :BEGIN$/ end=/^@AI :FINISH$/ contains=aiResponseStart,aiResponseEnd,@markdownTop fold

highlight aiResponseStart gui=bold guifg=#00FF00
highlight aiResponseEnd gui=bold guifg=#00FF00
