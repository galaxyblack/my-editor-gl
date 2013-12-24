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
    for _, view in ipairs(self.views) do
      if view.widget.is_focus then
        view.widget:queue_draw()
        self.redraw_time = current_time_in_millisecond()
        return
      end
    end
  end)

  function self.create_view(buf)
    local view = View(buf)
    view.widget:set_indent_width(self.default_indent_width)
    view.widget:modify_font(self.default_font)
    table.insert(self.views, view)
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

  function self.get_current_view()
    for _, view in ipairs(self.views) do
      if view.widget.is_focus then return view end
    end
  end

  -- buffer switching

  View.mix(function(view)
    view.define_signal('before-buffer-switch')
    function view.switch_to_buffer(buffer)
      view.emit_signal('before-buffer-switch', self.view_get_buffer(view))
      view.widget:set_buffer(buffer.buf)
      view.widget:set_indent_width(buffer.indent_width)
    end
  end)

  self.bind_command_key('>', function(args)
    local index = index_of(args.buffer, self.buffers)
    index = index + 1
    if index > #self.buffers then
      index = 1
    end
    args.view.switch_to_buffer(self.buffers[index])
  end, 'switch to next buffer')

  self.bind_command_key('<', function(args)
    local index = index_of(args.buffer, self.buffers)
    index = index - 1
    if index < 1 then
      index = #self.buffers
    end
    args.view.switch_to_buffer(self.buffers[index])
  end, 'switch to previous buffer')

  -- scroll

  self.bind_command_key('M', function(args)
    local alloc = args.view.widget:get_allocation()
    local buf = args.buffer.buf
    local view = args.view.widget
    local it = view:get_line_at_y(alloc.height - 50 + view:get_vadjustment():get_value())
    buf:place_cursor(it)
    view:scroll_to_mark(buf:get_insert(), 0, true, 1, 0)
  end, 'page down')

  self.bind_command_key('U', function(args)
    local alloc = args.view.widget:get_allocation()
    local buf = args.buffer.buf
    local view = args.view.widget
    local it = view:get_line_at_y(view:get_vadjustment():get_value() - alloc.height)
    buf:place_cursor(it)
    view:scroll_to_mark(buf:get_insert(), 0, true, 1, 0)
  end, 'page up')

  self.bind_command_key('gt', function(args)
    args.view.widget:scroll_to_mark(args.buffer.buf:get_insert(), 0, true, 1, 0)
  end, 'scroll cursor to screen top')
  self.bind_command_key('gb', function(args)
    args.view.widget:scroll_to_mark(args.buffer.buf:get_insert(), 0, true, 1, 1)
  end, 'scroll cursor to screen bottom')
  self.bind_command_key('gm', function(args)
    args.view.widget:scroll_to_mark(args.buffer.buf:get_insert(), 0, true, 1, 0.5)
  end, 'scroll cursor to middle of screen')

  -- auto scroll

  Buffer.mix(function(buffer)
    buffer.on_cursor_position(function() -- auto scroll to insert cursor
      for _, view in ipairs(self.views) do
        if self.view_get_buffer(view) ~= buffer then goto continue end
        if not view.widget.is_focus then goto continue end
        view.widget:scroll_to_mark(buffer.buf:get_insert(), 0, false, 0, 0)
        local scroll = view.scroll
        local vadj = scroll:get_vadjustment()
        ::continue::
      end
    end)
  end)

  View.mix(function(view)
    local buffer_scroll_state = {}
    function view.save_scroll_state()
      local buffer = self.gview_get_buffer(view.widget)
      local buf = buffer.buf
      local gview = view.widget
      local cursor_rect = gview:get_iter_location(buf:get_iter_at_mark(buf:get_insert()))
      local left, top = gview:buffer_to_window_coords(Gtk.TextWindowType.WIDGET,
        cursor_rect.x, cursor_rect.y)
      local alloc = gview:get_allocation()
      buffer_scroll_state[buffer.filename] = {
        buf:get_iter_at_mark(buf:get_insert()):get_offset(),
        left / alloc.width,
        top / alloc.height,
      }
    end
    function view.restore_scroll_state()
      local buffer = self.gview_get_buffer(view.widget)
      local buf = buffer.buf
      local state = buffer_scroll_state[buffer.filename]
      if not state then return end
      local it = buf:get_start_iter()
      it:set_offset(state[1])
      buf:place_cursor(it)
      if state[2] > 1 then state[2] = 1 end
      if state[3] > 1 then state[3] = 1 end --XXX top > alloc.height
      view.widget:scroll_to_mark(buf:get_insert(), 0, true, state[2], state[3])
    end
    view.on_focus_out(function() -- remember buffer scroll state
      view.save_scroll_state()
    end)
    view.on_focus_in(function() -- restore buffer scroll state
      view.restore_scroll_state()
    end)
    view.connect_signal('before-buffer-switch', function(buffer) -- remember buffer scroll state
      view.save_scroll_state()
    end)
    view.after_buffer_changed(function() -- restore buffer scroll state
      view.restore_scroll_state()
    end)
  end)

end

decl('View')
View = class{function(self, buf)
  if buf == nil then
    error('cannot create view without buffer')
  end
  self.widget = GtkSource.View.new_with_buffer(buf)
  self.proxy_gsignal(self.widget.on_draw, 'on_draw')
  self.proxy_gsignal(self.widget.on_notify, 'on_buffer_changed', 'buffer')
  self.proxy_gsignal(self.widget.on_notify, 'after_buffer_changed', 'buffer', true)
  self.proxy_gsignal(self.widget.on_grab_focus, 'on_grab_focus')
  self.proxy_gsignal(self.widget.on_focus_in_event, 'on_focus_in')
  self.proxy_gsignal(self.widget.on_focus_out_event, 'on_focus_out')

  local scroll = Gtk.ScrolledWindow()
  scroll:set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
  scroll:set_placement(Gtk.CornerType.TOP_RIGHT)
  scroll:set_vexpand(true)
  scroll:set_hexpand(true)
  scroll:add(self.widget)
  self.scroll = scroll

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
View.mix(signal_init)
