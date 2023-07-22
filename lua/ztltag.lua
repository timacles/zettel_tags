--
-- https://www.2n.pl/blog/how-to-write-neovim-plugins-in-lua
--

local api = vim.api
local buf, win
local currfile = api.nvim_buf_get_name(0)

local function OS()
    return package.config:sub(1,1) == "\\" and "win" or "unix"
end

local function center(str)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end

local function draw_title(str, width)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str .. string.rep(' ', shift + 1) 
end

local function open_window()
  buf = api.nvim_create_buf(false, true)
  local border_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'filetype', 'ztltag')

  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local border_opts = {
    style = "minimal",
    relative = "editor",
    width = win_width + 2,
    height = win_height + 2,
    row = row - 1,
    col = col - 1
  }

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height - 3,
    row = row  + 2,
    col = col
  }
  global_height = win_height -3 

  local border_lines = { '╭' .. string.rep('─', win_width) .. '╮' }
  local title_line = '│' .. draw_title('===>> ZTL Tag Searcher <<===', win_width) .. '│'
  local title_border = '│' ..  string.rep('─', win_width)  .. '│'
  local middle_line = '│' .. string.rep(' ', win_width) .. '│'
  table.insert(border_lines, title_line)
  table.insert(border_lines, title_border)
  for i=1, win_height - 3 do
    table.insert(border_lines, middle_line)
  end
  table.insert(border_lines, '╰' .. string.rep('─', win_width) .. '╯')
  api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

  local border_win = api.nvim_open_win(border_buf, true, border_opts)
  win = api.nvim_open_win(buf, true, opts)
  api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)

  --api.nvim_win_set_option(win, 'cursorline', true) -- it highlight line with the cursor on it
  api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:Normal')
  api.nvim_win_set_option(border_win, 'winhighlight', 'Normal:Normal,FloatBorder:Normal')

  -- Highlight for the title header
  api.nvim_buf_add_highlight(border_buf, -1, 'WarningMsg', 1, 3, win_width + 3)
end

local function update_view()
  api.nvim_buf_set_option(buf, 'modifiable', true)

  local result = tags_scan_from_file(currfile)
  if #result == 0 then table.insert(result, '') end -- add an empty line to preserve layout if there is no results
  api.nvim_buf_set_lines(buf, 0, -1, false, result)
  api.nvim_buf_set_option(buf, 'modifiable', false)

  highlight_make(tag_count)
end

function highlight_make()
    local width = api.nvim_win_get_width(0)
    highlight = {
        col_start = 0,
        ns_id = api.nvim_create_namespace('linehlight'),
        opts = {
          end_col = width,
          hl_group = 'StatusLine'
        }
    }
    highlight.opts.id = api.nvim_buf_set_extmark(buf, highlight.ns_id, 0, highlight.col_start, highlight.opts)
end    

function highlight_move(new_pos)
    api.nvim_buf_set_extmark(
        buf, 
        highlight.ns_id, 
        new_pos - 1 , 
        highlight.col_start, 
        highlight.opts)
end

local function close_window()
  api.nvim_win_close(win, true)
end

local function open_file()
  local str = api.nvim_get_current_line()
  close_window()
  api.nvim_command('edit '..str)
end

function move_cursor(new_pos)
    api.nvim_win_set_cursor(win, {new_pos, 0})
    highlight_move(new_pos)
end

function move_cursor_up()
    local new_pos = math.max(1, api.nvim_win_get_cursor(win)[1] - 1)
    move_cursor(new_pos)
end

function move_cursor_down()
    local new_pos = math.max(1, api.nvim_win_get_cursor(win)[1] + 1)
    if new_pos > #tags then new_pos = new_pos - 1 end -- prevent from going outside buffer
    move_cursor(new_pos)
end

function jump_to_cursor(num)

    -- concat new jump number if needed
    if numbuf == nil then
        numbuf = num 
    else 
        numbuf = tonumber(tostring(numbuf) .. tostring(num))
    end 

    -- reset if the jump number is outside bounds
    if numbuf < 1 or numbuf > #tags then
        numbuf = nil
        return
    end 

    move_cursor(numbuf)

    -- Reset the jump number buffer if it cant match any further values
    if tonumber(tostring(numbuf) .. '0') > #tags then
        numbuf = nil
    end

end


local function set_mappings()
  local mappings = {
    ['<cr>']   = 'tag_vim_search()',
    q          = 'close_window()',
    ['<Up>']   = 'move_cursor_up()',
    ['<Down>'] = 'move_cursor_down()'
  }

  for i=0, 9, 1 do
    local istr = tostring(i)
    mappings[istr] = 'jump_to_cursor('..istr..')'
  end

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"ztltag".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
  local other_chars = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
  }
  for k,v in ipairs(other_chars) do
    api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
  end
end

local function ztltag()
  open_window()
  set_mappings()
  update_view()
  api.nvim_win_set_cursor(win, {1, 0})
end

------------------------------------------------
-- Scan the file for tags for display and search
------------------------------------------------
function tags_scan_from_file(file)

    -- First iterate over the file and parse the tags with regex
    local contents = {}
    for line in io.lines(file) do 
        for tag in line:gmatch("%[%[.-%]%]") do
            contents[#contents + 1] = tag_strip(tag)
        end 
    end

    -- Using the tags as a key, count each occurence
    local counts = {} 
    for _, v in pairs(contents) do
        -- check if tag exists first 
        if counts[v] == nil then
            counts[v] = 1
        else 
            counts[v] = counts[v] + 1
        end
    end 

    -- Create our ordered tag index as a global variable
    tags = {}
    for k, _ in pairs(counts) do
        tags[#tags + 1] = k 
    end 
    table.sort(tags)

    -- Create labels by using the tag index 
    local labels = {}
    for k, v in pairs(tags) do
        --labels[k] = k..": "..v.."    -> "..counts[v]         
        labels[k] = k..": "..v.."    -> "..counts[v]         
    end

    nlabels = draw_labels(tags, counts)

    return nlabels
end

--------------------------------------
-- Draw the tag labels for the display
-- Right align the counts 
--------------------------------------
function draw_labels(tags, counts)
    local width = api.nvim_win_get_width(0)
    local labels = {}
    for k, v in pairs(tags) do 
        local idx = tostring(k)
        if string.len(idx) == 1 then idx = ' '..idx end
        local count = tostring(counts[v])
        if string.len(count) == 1 then count = ' '..count end 
        local tag_text = idx..': '..v
        local shift = width - string.len(tag_text) -2
        labels[k] = tag_text..string.rep(' ', shift)..count
    end
    return labels
end 

-- Do a VIM search command on the selected tag
local function tag_vim_search()
  -- reset the cursor jump number buffer
  numbuf = nil
  -- Get the tag index from the current line 
  local line = api.nvim_get_current_line()
  local idx = tonumber(line:match('(.*):'))
  local tag = tags[idx]
  -- Close the popup window and perform search 
  close_window()
  api.nvim_feedkeys(api.nvim_eval('"\\/'..tag..'\\<CR>"'), 'm', ture)
end

-- Strip brackets from tags
function tag_strip(tag)
    if tag == nil then
        return 
    end
    tag = tag:gsub("%[%[", "")
    tag = tag:gsub("%]%]", "")
    return tag
end 

return {
  ztltag = ztltag,
  update_view = update_view,
  open_file = open_file,
  move_cursor_up = move_cursor_up,
  move_cursor_down = move_cursor_down,
  jump_to_cursor = jump_to_cursor,
  close_window = close_window,
  tag_vim_search = tag_vim_search
}

