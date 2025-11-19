" Command definitions (:Zournal* commands)
" This file will be loaded automatically by Neovim

if exists('g:loaded_zournal')
  finish
endif
let g:loaded_zournal = 1

" Journal commands
command! ZournalDailyJournal lua require('zournal.journal').create_daily_journal()
command! ZournalWeeklyJournal lua require('zournal.journal').create_weekly_journal()
command! ZournalMonthlyJournal lua require('zournal.journal').create_monthly_journal()
command! ZournalInbox lua require('zournal.journal').create_inbox_note()

" Zettelkasten commands
command! ZournalNewChild lua require('zournal.zettelkasten').create_child_note()
command! ZournalNewSibling lua require('zournal.zettelkasten').create_sibling_note()
command! ZournalAddParent lua require('zournal.zettelkasten').add_parent_relationship()

" Telescope integration commands
command! ZournalRelations lua require('zournal.telescope.relations').pick_relations()
command! ZournalLinks lua require('zournal.telescope.links').pick_links()

" Tagging commands
command! ZournalTagAdd lua require('zournal.tags').add_tag()
command! ZournalTagCopy lua require('zournal.tags').copy_tag_reference()
command! ZournalTagReferences lua require('zournal.telescope.tag_references').pick_tag_references()

" Virtual text commands
command! ZournalVirtualTextShow lua require('zournal.virtual_text').update_virtual_text(0)
command! ZournalVirtualTextClear lua require('zournal.virtual_text').clear_virtual_text(0)
command! ZournalVirtualTextToggle lua require('zournal.virtual_text').toggle()

" Navigation commands
command! -nargs=? ZournalJumpToDate lua require('zournal.journal').jump_to_date(<f-args>)
command! ZournalFollowLink lua require('zournal.links').follow_link()

" Workspace management commands
command! -nargs=1 ZournalSelectWorkspace lua require('zournal.config').set_active_workspace(<f-args>)
command! ZournalListWorkspaces lua require('zournal.workspace').list_workspaces()
command! ZournalCurrentWorkspace lua require('zournal.workspace').show_current_workspace()
