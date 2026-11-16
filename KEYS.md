# Keys

One rule per modifier. `keys` prints this page; Cmd-/ shows it from anywhere.

    Cmd            the workspace: projects, windows, panes, popups
    Ctrl-h/j/k/l   move to the neighbouring split or pane
    Alt-h/j/k/l    resize it
    Space          actions on code, in Neovim
    Ctrl-letter    fuzzy-insert into the command line, in fish

## Workspace (Cmd, in a shell or in Neovim)

    Cmd-K              pick a project; a new one opens in Neovim, resumed
    Cmd-T              new window
    Cmd-1 … 9          go to window
    Cmd-Shift-[ ]      previous, next window
    Cmd-D              split right
    Cmd-Shift-D        split down
    Cmd-J              show or hide the shell pane under the editor
    Cmd-W              close what is in front: buffer in Neovim, else the pane
    Cmd-G              lazygit
    Cmd-F              search: the file in Neovim, else the scrollback
    Cmd-↑              jump to the previous prompt in the scrollback
    Cmd-Enter          full screen ↔ left half (PDF on the right)
    Cmd-/              this page

    Scrollback (after Cmd-F or Cmd-↑): v select, y copy, [ ] prompts, q quit
    tmux prefix Ctrl-B, rarely needed: d detach, , rename, z zoom the pane

## Shell (fish, vi mode)

    Ctrl-T             insert a file path
    Ctrl-R             search history
    Ctrl-G             grep the project, Enter opens the hit in Neovim
    Ctrl-F or →        accept the suggestion; Alt-F one word of it
    cd <part>          jump to a directory you've been in (zoxide)

## Neovim: find

    Space Space        file            Space /      grep
    Space ,            open buffers    Space `      previous buffer
    Space e            explorer        Space fr     recent files
    Space 1 … 9        pinned file     Space H      pin this file
    Space h            edit the pins   H  L         previous, next buffer
    Space sR           reopen the last picker
    Space ss           symbols in file Space sS     symbols in project
    Space sw           grep the word under the cursor
    Space sr           search and replace

## Neovim: move and edit

    s + 2 chars        jump anywhere on screen (flash)
    S                  select a syntax node
    gd  gr  gI  gy     definition, references, implementation, type
    K                  hover docs       Ctrl-O  Ctrl-I   back, forward
    ]d [d  ]e [e       next/previous diagnostic, error
    ]f [f  ]c [c       next/previous function, class
    gsa gsd gsr        add, delete, replace surrounding
    gcc  gc            comment line, selection
    Space cr           rename           Space ca     code action
    Space cf           format           Space cd     line diagnostics
    Tab                next edit suggestion (Copilot)
    Enter              accept completion

## Neovim: run, test, debug

    Space rr           run on input.txt        Space rt   run every testcase
    Space ra           save input.txt as case  Space re   edit a case
    Space rf           failing case → input    Space ri   edit input.txt
    Space rp           run without sanitizers  Space rk   kill
    Space tt  tr  tl   test file, nearest, last
    Space db           breakpoint              Space dc   debug (builds a single file), continue
    Space di do dO     step in, out, over      Space dC   run to the cursor
    Space du           debugger panels         Space dt   stop

## Neovim: git and AI

    Cmd-G              lazygit                 Space gb   blame line
    Space gd           changed hunks           Space gf   file history
    ]h [h              next/previous hunk
    Space ac  ax       Claude, Codex           Space at   send this
    Space af  av       send file, selection    Ctrl-.     focus the AI pane

## LaTeX

    Open a .tex file   it compiles on every save and Skim opens beside the editor
    Space lv           show the PDF at the cursor
    Cmd-Shift-click    in Skim: jump to that line in Neovim
    Space le           errors                  Space lt   table of contents

## Practice sessions (`lc`, `nvt`)

    Space jj  jl       LeetCode menu, problem list
    Space jr           run the samples locally (generates the harness)
    Space jR  js       run on LeetCode, submit
    Space ja  je       add, edit a local case
    Space rv           receive a problem from the browser (Competitive Companion)

Anything else: press Space and wait, which-key lists the rest.
