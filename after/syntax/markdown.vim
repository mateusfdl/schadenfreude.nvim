syntax match aiResponseStart /^@AI :BEGIN/ contained conceal cchar=󱙺
syntax match aiResponseId /== ID:[0-9]\{10\}/ contained
syntax match aiResponseEnd /^@AI :FINISH$/ contained conceal
syntax region aiResponse start=/^@AI :BEGIN/ end=/^@AI :FINISH$/ contains=aiResponseStart,aiResponseId,aiResponseEnd,@markdownTop fold

highlight aiResponseStart gui=bold guifg=#00FF00
highlight aiResponseId gui=italic guifg=#8888FF
highlight aiResponseEnd gui=bold guifg=#00FF00
