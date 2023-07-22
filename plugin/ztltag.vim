" plugin/ztltag.vim
if exists('g:loaded_ztltag') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

hi def link ZtlTagHeader      Number
hi def link ZtlTagSubHeader   Identifier

command! Ztag lua require'ztltag'.ztltag()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_ztltag = 1
