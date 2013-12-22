require 'core.defs'
require 'core.buffer'
require 'core.key'
require 'core.view'
require 'core.edit'
require 'core.status'
require 'core.layout'
require 'core.file'
require 'core.message'
require 'core.format'
require 'core.search'
require 'core.word_collector'
require 'core.bookmark'
require 'core.completion'
require 'core.iter'
require 'core.selection'
require 'core.transform'
require 'core.operation'
require 'core.macro'
require 'core.pattern'
require 'core.terminal'
require 'core.folding'
require 'core.snippet'

decl('Editor')
Editor = class{
  signal_init,
  function(self)
    self.widget = Gtk.Overlay()
    self.proxy_gsignal(self.widget.on_realize, 'on_realize')

    function self.create_overlay_label(halign, valign)
      local label = Gtk.Label{halign = halign, valign = valign}
      self.widget:add_overlay(label)
      self.on_realize(function()
        label:hide()
      end)
      return label
    end

    -- root grid
    self.root_grid = Gtk.Grid()
    self.widget:add(self.root_grid)

    -- areas
    self.east_area = Gtk.Grid()
    self.root_grid:attach(self.east_area, 1, 0, 1, 1)
    self.west_area = Gtk.Grid()
    self.root_grid:attach(self.west_area, -1, 0, 1, 1)
    self.north_area = Gtk.Grid()
    self.root_grid:attach(self.north_area, 0, -1, 2, 1)
    self.south_area = Gtk.Grid()
    self.root_grid:attach(self.south_area, 0, 1, 2, 1)

  end,

  -- core modules
  core_defs_init,
  core_buffer_init,
  core_key_init,
  core_view_init,
  core_edit_init,
  core_status_init,
  core_layout_init,
  core_file_init,
  core_message_init,
  core_format_init,
  core_search_init,
  core_word_collector_init,
  core_bookmark_init,
  core_completion_init,
  core_iter_init,
  core_selection_init,
  core_transform_init,
  core_operation_init,
  core_macro_init,
  core_pattern_init,
  core_terminal_init,
  core_folding_init,
  core_snippet_init,

  function(self)

    -- views
    self.views_grid = Gtk.Grid()
    self.views_grid:set_row_homogeneous(true)
    self.views_grid:set_column_homogeneous(true)
    self.root_grid:attach(self.views_grid, 0, 0, 1, 1)

    -- font and style
    self.style_scheme_manager = GtkSource.StyleSchemeManager.get_default()
    self.style_scheme_manager:append_search_path(joinpath(program_path(), 'theme'))
    self.style_scheme = self.style_scheme_manager:get_scheme(self.default_scheme)

    -- extra modules

    -- buffers
    each(function(filename)
      self.create_buffer(filename)
    end, argv())
    if #self.buffers == 0 then
      self.create_buffer()
    end

    -- first view
    local view = self.create_view(self.buffers[1].buf)
    self.views_grid:add(view.wrapper)

  end,
}
Editor.embed('widget')
