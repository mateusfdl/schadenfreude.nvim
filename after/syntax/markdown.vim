syntax match aiResponseStart /^@AI :BEGIN/ contained conceal cchar=󱙺
syntax match aiResponseId /== ID:[a-z0-9]\+/ contained conceal
syntax match aiResponseModel /== MODEL:\w\+/ contained
syntax match aiResponseModelName /\w\+/ contained containedin=aiResponseModel
syntax match aiResponseEnd /^@AI :FINISH$/ contained conceal
syntax region aiResponse start=/^@AI :BEGIN/ end=/^@AI :FINISH$/ contains=aiResponseStart,aiResponseId,aiResponseModel,aiResponseModelName,aiResponseEnd,opSearchContent,opReplaceContent,opAddContent,opDeleteContent,opAtLineContent,@markdownTop fold

highlight aiResponseStart gui=bold guifg=#00FF00
highlight aiResponseId gui=italic guifg=#8888FF
highlight aiResponseModel guifg=NONE
highlight aiResponseModelName gui=bold guifg=#00FF00
highlight aiResponseEnd gui=bold guifg=#00FF00
