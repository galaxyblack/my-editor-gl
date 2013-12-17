decl('core_view_init')
function core_view_init(self)
  self.views = {}
  self._views_map = {}

  self.define_signal('view-created')
  self.connect_signal('view-created', function(view)
    self.gconnect(view.on_key_press_event, self.handle_key)
  end)

  -- view redraw
  self.define_signal('should-redraw')
  -- redraw current view
  self.redraw_time = current_time_in_millisecond()
  self.connect_signal('should-redraw', function()
    if current_time_in_millisecond() - self.redraw_time < 20 then return end
    for _, view in pairs(self.views) do
      if view.widget.is_focus then
        view.widget:queue_draw()
        self.redraw_time = current_time_in_millisecond()
      end
    end
  end)

  function self.create_view(buf)
    local view = View(buf)
    view.widget:set_indent_width(self.default_indent_width)
    view.widget:modify_font(self.default_font)
    table.insert(self.views, view)
    --TODO update buffer list
    self.emit_signal('view-created', view)
    self._views_map[view.widget] = view
    return view
  end

  function self.gview_to_View(gview)
    return self._views_map[gview]
  end

  function self.gview_get_buffer(gview)
    local gbuffer = gview:get_buffer()
    return self.gbuffer_to_Buffer(gbuffer)
  end

  function self.view_get_buffer(view)
    return self.gbuffer_to_Buffer(view.widget:get_buffer())
  end

  -- buffer switching
  local function switch_buffer(view, buffer)
    view.widget:set_buffer(buffer.buf)
    view.widget:set_indent_width(buffer.indent_width)
  end

  self.bind_command_key('>', function(args)
    local index = index_of(self.buffers, args.buffer)
    index = index + 1
    if index > #self.buffers then
      index = 1
    end
    switch_buffer(args.view, self.buffers[index])
  end, 'switch to next buffer')

  self.bind_command_key('<', function(args)
    local index = index_of(self.buffers, args.buffer)
    index = index - 1
    if index < 1 then
      index = #self.buffers
    end
    switch_buffer(args.view, self.buffers[index])
  end, 'switch to previous buffer')

  -- scroll
  self.bind_command_key('M', function(args)
    local alloc = args.view.widget:get_allocation()
    local buf = args.buffer.buf
    local view = args.view.widget
    local it = view:get_line_at_y(alloc.height - 50 + view:get_vadjustment():get_value())
    buf:place_cursor(it)
    view:scroll_to_mark(buf:get_insert(), 0, true, 0, 0)
  end, 'page down')

  self.bind_command_key('U', function(args)
    local alloc = args.view.widget:get_allocation()
    local buf = args.buffer.buf
    local view = args.view.widget
    local it = view:get_line_at_y(view:get_vadjustment():get_value() - alloc.height)
    buf:place_cursor(it)
    view:scroll_to_mark(buf:get_insert(), 0, true, 0, 0)
  end, 'page up')

end

decl('View')
View = class{function(self, buf)
  if buf == nil then
    error('cannot create view without buffer')
  end
  self.widget = GtkSource.View.new_with_buffer(buf)

  local scroll = Gtk.ScrolledWindow()
  scroll:set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
  scroll:set_placement(Gtk.CornerType.TOP_RIGHT)
  scroll:set_vexpand(true)
  scroll:set_hexpand(true)
  scroll:add(self.widget)

  local overlay = Gtk.Overlay()
  overlay:set_vexpand(true)
  overlay:set_hexpand(true)
  overlay:add(scroll)

  self.wrapper = overlay
  self.overlay = overlay

  self.widget:set_auto_indent(true)
  self.widget:set_indent_on_tab(true)
  self.widget:set_insert_spaces_instead_of_tabs(true)
  self.widget:set_smart_home_end(GtkSource.SmartHomeEndType.BEFORE)
  self.widget:set_show_line_marks(false)
  self.widget:set_show_line_numbers(true)
  self.widget:set_tab_width(2)
  self.widget:set_wrap_mode(Gtk.WrapMode.NONE)
end}
View.embed('widget')
