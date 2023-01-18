" Display your APM (Actions Per Minute) and
" recent key strokes
"
" Author:       pseudoc <atlas.yu@canonical.com>
" Version:      0.2.2
" License:      MIT
" Repository:   https://github.com/pseudocc/nvim-apm

if exists('g:nvim_apm_is_ready') || &cp
  if g:nvim_apm_is_ready
    finish
  endif
endif

let g:nvim_apm_is_ready = 1

func! s:NvimApmStart()
  lua require('nvim-apm').apm_start()
endf

func! s:NvimApmStop()
  lua require('nvim-apm').apm_stop()
  lua package.loaded['nvim-apm'] = nil
  lua package.loaded['nvim-apm.buckets'] = nil
  lua package.loaded['nvim-apm.list'] = nil
endf

func! s:NvimApmToggle()
  lua require('nvim-apm').apm_toggle()
endf

command! NvimApm call s:NvimApmStart()
command! NvimApmStop call s:NvimApmStop()
command! NvimApmToggle call s:NvimApmToggle()

augroup NvimApmGroup
  autocmd!
  autocmd WinClosed * :lua require('nvim-apm').win_close(vim.fn.expand('<afile>'))
  autocmd VimResized * :lua require('nvim-apm').resize()
augroup END
