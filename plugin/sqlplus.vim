" sqlplus.vim
" author: Jamis Buck (jgb3@email.byu.edu)
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
"   :Select <query> -- execute the given Select query.
"   :DB <db-name> -- set the database name to <db-name>
"
" In visual mode:
"   <F8>: execute the selected query
"
" If queries contain bind variables, you will be prompted to give a value for each
" one.  if the value is a string, you must explicitly put quotes around it.  If the
" query contains an INTO clause, it is removed before executing.
"
" You will be prompted for your user-name and password the first time you access
" one of these functions during a session.  After that, your user-id and password
" will be remembered until the session ends.
"
" The results of the query/command are displayed in a separate window.

let s:sqlplus_userid = ""
let s:sqlplus_passwd = ""
let s:sqlplus_path   = $ORACLE_HOME . "/bin/sqlplus -s "
let s:sqlplus_common_commands = "set pagesize 10000\nset wrap off\nset linesize 9999\n"

let g:sqlplus_db     = $ORACLE_SID

function! AE_getSQLPlusUIDandPasswd( force )
  if s:sqlplus_userid == "" || a:force != 0
    let l:userid = substitute( system( "whoami" ), "\n", "", "g" )
    let s:sqlplus_userid = input( "Please enter your SQL*Plus user-id:  ", l:userid )
    let s:sqlplus_passwd = inputsecret( "Please enter your SQL*Plus password:  " )
  endif
endfunction

function! AE_configureOutputWindow()
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
endfunction

function! AE_describeTable( tableName )
  let l:cmd = "prompt DESCRIBING TABLE '" . a:tableName . "'\ndesc " . a:tableName
  call AE_execQuery( l:cmd )
endfunction

function! AE_describeTableUnderCursor()
  normal viw"zy
  call AE_describeTable( @z )
endfunction

function! AE_describeTablePrompt()
  let l:tablename = input( "Please enter the name of the table to describe:  " )
  call AE_describeTable( l:tablename )
endfunction

function! AE_execQuery( sql_query )
  call AE_getSQLPlusUIDandPasswd( 0 )
  new
  let l:tmpfile = tempname()
  let l:oldo = @o
  let @o="i" . s:sqlplus_common_commands . a:sql_query . ";\n"
  normal @o
  let @o=l:oldo
  exe "silent write " . l:tmpfile
  close
  new
  let l:cmd = s:sqlplus_path . s:sqlplus_userid . "/" . s:sqlplus_passwd . "@" . g:sqlplus_db
  let l:cmd = l:cmd . " < " . l:tmpfile
  exe "1,$!" . l:cmd
  call AE_configureOutputWindow()
  call delete( l:tmpfile )
endfunction

function! AE_promptQuery()
  let l:sqlquery = input( "SQL Query: " )
  call AE_execQuery( l:sqlquery )
endfunction

function! AE_resetPassword()
  let s:sqlplus_userid = ""
  let s:sqlplus_passwd = ""
endfunction

function! AE_execLiteralQuery( sql_query )
  let l:query = substitute( a:sql_query, '\c\<INTO\>.*\<FROM\>', 'FROM', 'g' )

  let l:idx = stridx( l:query, "\n" )
  while l:idx >= 0
    let l:query = strpart( l:query, 0, l:idx ) . strpart( l:query, l:idx+1 )
    let l:idx = stridx( l:query, "\n" )
  endwhile

  let l:var = matchstr( l:query, ':\h\w*' )
  while l:var > ""
    let l:var_val = input( "Enter value for " . strpart( l:var, 1 ) . ": " )
    let l:query = substitute( l:query, l:var . '\>', l:var_val, 'g' )
    let l:var = matchstr( l:query, ':\h\w*' )
  endwhile

  call AE_execQuery( l:query )
endfunction

function! AE_execQueryUnderCursor()
  exe "silent norm! ?\\c[^.]\\<select\\>\nv/;\nh\"zy"
  noh
  call AE_execLiteralQuery( sql_query )
endfunction


map <F8>  :call AE_execQueryUnderCursor()<CR>
map <Leader><F8> :call AE_promptQuery()<CR>
map <F9>  :call AE_describeTableUnderCursor()<CR>
map <F10> :call AE_describeTablePrompt()<CR>

vmap <F8> "zy:call AE_execLiteralQuery( @z )<CR>

command! -nargs=* Select :call AE_execQuery( "select <a>" )
command! -nargs=1 DB     :let g:sqlplus_db=<args>

