" sqlplus.vim
" author: Jamis Buck (jgb3@email.byu.edu)
" version: 1.2.3
"
" This file contains routines that may be used to execute SQL queries and describe
" tables from within VIM.  It depends on SQL*Plus.  You must have $ORACLE_HOME
" $ORACLE_SID set in your environment, although you can explicitly set the
" database name to use with the :DB <db-name> command.
"
" In command mode:
"   <F8>: execute the SELECT query under your cursor.  The query must begin with
"         the "select" keyword and end with a ";"
"   <Leader><F8>: prompt for an SQL command/query to execute.
"   <F9>: treat the identifier under the cursor as a table name, and do a 'describe'
"         on it.
"   <F10>: prompt for a table to describe.
"   <F11>: set the current SQL*Plus username and password
"   <Leader>sb: open an empty buffer in a new window to enter SQL commands in
"   <Leader>ss: execute the (one-line) query on the current line
"   <Leader>se: execute the query under the cursor (as <F8>)
"   <Leader>st: describe the table under the cursor (as <F9>)
"   <Leader>sc: open the user's common SQL buffer (g:sqlplus_common_buffer) in a
"               new window.
"
"   :Select <...> -- execute the given Select query.
"   :Update <...> -- execute the given Update command.
"   :Delete <...> -- execute the given Delete command
"   :DB <db-name> -- set the database name to <db-name>
"   :SQL <...> -- open a blank SQL buffer in a new window, or if a filename is
"                 specified, open the given file in a new window.
"
" In visual mode:
"   <F8>: execute the selected query
"
" Command mode abbreviations also exist, so you can use :select instead of
" :Select, :update instead of :Update, :db instead of :DB, and :sql instead
" of :SQL.  Unfortunately, :delete is already taken, so it could not be
" remapped.
"
" If queries contain bind variables, you will be prompted to give a value for
" each one.  if the value is a string, you must explicitly put quotes around it.
" If the query contains an INTO clause, it is removed before executing.
"
" You will be prompted for your user-name and password the first time you access
" one of these functions during a session.  After that, your user-id and password
" will be remembered until the session ends.
"
" The results of the query/command are displayed in a separate window.
"
" You can specify the values of the following global variables in your .vimrc
" file, to alter the behavior of this plugin:
"
"   g:sqlplus_userid -- the user-id to log in to the database as.  If this
"       is specified, g:sqlplus_passwd must be given as well, which is the
"       password to use.  Default: ""
"   g:sqlplus_path -- the path the the SQL*Plus executable, including any
"       command line options.  Default: $ORACLE_HOME . "/bin/sqlplus -s"
"   g:sqlplus_common_commands -- any SQL*Plus commands that should be
"       executed every time SQL*Plus is invoked.
"       Default: "set pagesize 10000\nset wrap off\nset linesize 9999\n"
"   g:sqlplus_common_buffer -- the name of a file that will contain
"       common SQL queries and expressions, that may be opened via the
"       <Leader>sc command.
"   g:sqlplus_db -- the name of the database to connect to.  This variable
"       may also be modified via the :DB command.
"
" ------------------------------------------------------------------------------
" Thanks to:
"   Matt Kunze (kunzem@optimiz.com) for getting this script to work under
"     Windows
" ------------------------------------------------------------------------------


" Global variables (may be set in ~/.vimrc) {{{1
if !exists( "g:sqlplus_userid" )
  let g:sqlplus_userid = ""
  let g:sqlplus_passwd = ""
endif
if !exists( "g:sqlplus_path" )
  let g:sqlplus_path = $ORACLE_HOME . "/bin/sqlplus -s "
endif
if !exists( "g:sqlplus_common_commands" )
  let g:sqlplus_common_commands = "set pagesize 10000\nset wrap off\nset linesize 9999\n"
endif
if !exists( "g:sqlplus_common_buffer" )
  let g:sqlplus_common_buffer = "~/.vim_sql"
endif
if !exists( "g:sqlplus_db" )
  let g:sqlplus_db = $ORACLE_SID
endif
"}}}

function! AE_getSQLPlusUIDandPasswd( force ) "{{{1
  if g:sqlplus_userid == "" || a:force != 0
    if has("win32")
      let l:userid = ''
    else
      let l:userid = substitute( system( "whoami" ), "\n", "", "g" )
    endif
    let g:sqlplus_userid = input( "Please enter your SQL*Plus user-id:  ", l:userid )
    let g:sqlplus_passwd = inputsecret( "Please enter your SQL*Plus password:  " )
  endif
endfunction "}}}

function! AE_configureOutputWindow() "{{{1
  set ts=8 buftype=nofile nowrap sidescroll=5 listchars+=precedes:<,extends:>
  normal $G
  while getline(".") == ""
    normal dd
  endwhile
  normal 1G
  let l:newheight = line("$")
  if l:newheight < winheight(0)
    exe "resize " . l:newheight
  endif
endfunction "}}}

function! AE_configureSqlBuffer() "{{{1
  set syn=sql
endfunction "}}}

function! AE_describeTable( tableName ) "{{{1
  let l:cmd = "prompt DESCRIBING TABLE '" . a:tableName . "'\ndesc " . a:tableName
  call AE_execQuery( l:cmd )
endfunction "}}}

function! AE_describeTableUnderCursor() "{{{1
  normal viw"zy
  call AE_describeTable( @z )
endfunction "}}}

function! AE_describeTablePrompt() "{{{1
  let l:tablename = input( "Please enter the name of the table to describe:  " )
  call AE_describeTable( l:tablename )
endfunction "}}}

function! AE_execQuery( sql_query ) "{{{1
  call AE_getSQLPlusUIDandPasswd( 0 )
  new
  let l:tmpfile = tempname() . ".sql"
  let l:oldo = @o
  let @o="i" . g:sqlplus_common_commands . a:sql_query
  let l:pos = match( @o, ";$" )
  if l:pos < 0
    let @o=@o . ";"
  endif
  let @o=@o . "\n"
  normal @o
  let @o=l:oldo
  exe "silent write " . l:tmpfile
  close
  new
  let l:cmd = g:sqlplus_path . g:sqlplus_userid . "/" . g:sqlplus_passwd . "@" . g:sqlplus_db
  let l:cmd = l:cmd . " @" . l:tmpfile
  exe "1,$!" . l:cmd
  call AE_configureOutputWindow()
  call delete( l:tmpfile )
endfunction "}}}

function! AE_promptQuery() "{{{1
  let l:sqlquery = input( "SQL Query: " )
  call AE_execQuery( l:sqlquery )
endfunction "}}}

function! AE_resetPassword() "{{{1
  let g:sqlplus_userid = ""
  let g:sqlplus_passwd = ""
endfunction "}}}

function! AE_execLiteralQuery( sql_query ) "{{{1
  let l:query = substitute( a:sql_query, '\c\<INTO\>.*\<FROM\>', 'FROM', 'g' )

  let l:idx = stridx( l:query, "\n" )
  while l:idx >= 0
    let l:query = strpart( l:query, 0, l:idx ) . " " . strpart( l:query, l:idx+1 )
    let l:idx = stridx( l:query, "\n" )
  endwhile

  let l:var = matchstr( l:query, ':\h\w*' )
  while l:var > ""
    let l:var_val = input( "Enter value for " . strpart( l:var, 1 ) . ": " )
    let l:query = substitute( l:query, l:var . '\>', l:var_val, 'g' )
    let l:var = matchstr( l:query, ':\h\w*' )
  endwhile

  call AE_execQuery( l:query )
endfunction "}}}

function! AE_execQueryUnderCursor() "{{{1
  exe "silent norm! ?\\c[^.]*\\<\\(select\\|update\\|delete\\)\\>\nv/;\nh\"zy"
  noh
  call AE_execLiteralQuery( @z )
endfunction "}}}

function! AE_openSqlBuffer( fname ) "{{{1
  exe "new " . a:fname
  call AE_configureSqlBuffer()
endfunction "}}}

function! AE_openEmptySqlBuffer() "{{{1
  call AE_openSqlBuffer( "" )
endfunction "}}}


" command-mode mappings {{{1
map <Leader>sb   :call AE_openEmptySqlBuffer()<CR>
map <Leader>ss   "zyy:call AE_execLiteralQuery( @z )<CR>
map <Leader>se   :call AE_execQueryUnderCursor()<CR>
map <Leader>st   :call AE_describeTableUnderCursor()<CR>
exe "map <Leader>sc   :call AE_openSqlBuffer( \"" . g:sqlplus_common_buffer . "\" )<CR>"

map <F8>  :call AE_execQueryUnderCursor()<CR>
map <Leader><F8> :call AE_promptQuery()<CR>
map <F9>  :call AE_describeTableUnderCursor()<CR>
map <F10> :call AE_describeTablePrompt()<CR>
map <F11> :call AE_getSQLPlusUIDandPasswd(1)<CR>
"}}}

" visual mode mappings {{{1
vmap <F8> "zy:call AE_execLiteralQuery( @z )<CR>
"}}}

" commands {{{1
command! -nargs=+ Select :call AE_execQuery( "select <a>" )
command! -nargs=+ Update :call AE_execQuery( "update <a>" )
command! -nargs=+ Delete :call AE_execQuery( "delete <a>" )
command! -nargs=1 DB     :let  g:sqlplus_db="<args>"
command! -nargs=? SQL    :call AE_openSqlBuffer( "<args>" )

cabbrev select Select
cabbrev update Update
cabbrev db     DB
cabbrev sql    SQL
"}}}
