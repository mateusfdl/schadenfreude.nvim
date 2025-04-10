syntax match aiResponseStart /^@AI :BEGIN/ contained conceal cchar=󱙺
syntax match aiResponseId /== ID:[a-z]*-[0-9]\{10\}/ contained
syntax match aiResponseEnd /^@AI :FINISH$/ contained conceal
syntax region aiResponse start=/^@AI :BEGIN/ end=/^@AI :FINISH$/ contains=aiResponseStart,aiResponseId,aiResponseEnd,opSearchContent,opReplaceContent,opAddContent,opDeleteContent,opAtLineContent,@markdownTop fold

" Define syntax for operation tags
syntax match opTagSearchStart /<|SEARCH|>/ contained
syntax match opTagSearchEnd /<\/|SEARCH|>/ contained
syntax match opTagReplaceStart /<|REPLACE|>/ contained
syntax match opTagReplaceEnd /<\/|REPLACE|>/ contained
syntax match opTagAddStart /<|ADD|>/ contained
syntax match opTagAddEnd /<\/|ADD|>/ contained
syntax match opTagDeleteStart /<|DELETE|>/ contained
syntax match opTagDeleteEnd /<\/|DELETE|>/ contained
syntax match opTagAtLineStart /<|AT_LINE|>/ contained
syntax match opTagAtLineEnd /<\/|AT_LINE|>/ contained

" Define regions for operation content
syntax region opSearchContent matchgroup=opTagSearchStart start=/<|SEARCH|>/ matchgroup=opTagSearchEnd end=/<\/|SEARCH|>/ keepend
syntax region opReplaceContent matchgroup=opTagReplaceStart start=/<|REPLACE|>/ matchgroup=opTagReplaceEnd end=/<\/|REPLACE|>/ keepend
syntax region opAddContent matchgroup=opTagAddStart start=/<|ADD|>/ matchgroup=opTagAddEnd end=/<\/|ADD|>/ keepend
syntax region opDeleteContent matchgroup=opTagDeleteStart start=/<|DELETE|>/ matchgroup=opTagDeleteEnd end=/<\/|DELETE|>/ keepend
syntax region opAtLineContent matchgroup=opTagAtLineStart start=/<|AT_LINE|>/ matchgroup=opTagAtLineEnd end=/<\/|AT_LINE|>/ keepend

" Color for operation tags - git-like coloring
highlight opTagSearchStart gui=bold guifg=#E2A478 guibg=#3E4452
highlight opTagSearchEnd gui=bold guifg=#E2A478 guibg=#3E4452
highlight opTagReplaceStart gui=bold guifg=#5CCFE6 guibg=#3E4452
highlight opTagReplaceEnd gui=bold guifg=#5CCFE6 guibg=#3E4452
highlight opTagAddStart gui=bold guifg=#7EC16E guibg=#324932 " Green for additions
highlight opTagAddEnd gui=bold guifg=#7EC16E guibg=#324932
highlight opTagDeleteStart gui=bold guifg=#F07178 guibg=#493232 " Red for deletions
highlight opTagDeleteEnd gui=bold guifg=#F07178 guibg=#493232
highlight opTagAtLineStart gui=bold guifg=#D4D4D4 guibg=#3E4452
highlight opTagAtLineEnd gui=bold guifg=#D4D4D4 guibg=#3E4452

" Content highlighting with background colors
highlight opSearchContent guifg=#E2A478 guibg=#2F3237
highlight opReplaceContent guifg=#5CCFE6 guibg=#2F3237
highlight opAddContent guifg=#7EC16E guibg=#263626 " Green background for additions
highlight opDeleteContent guifg=#F07178 guibg=#362626 " Red background for deletions
highlight opAtLineContent guifg=#D4D4D4 guibg=#2F3237

" Original AI response highlighting
highlight aiResponseStart gui=bold guifg=#00FF00
highlight aiResponseId gui=italic guifg=#8888FF
highlight aiResponseEnd gui=bold guifg=#00FF00