# preferences_app.rb
#
# Module 2 Capstone — Preferences Panel
# wxRuby3 Desktop Development Tutorial Series
#
# A complete preferences dialog demonstrating:
#   - Wx::Notebook tabbed layout
#   - Core widgets across four preference categories
#   - OK / Cancel / Apply with dirty state tracking
#   - Widget enabling/disabling in response to user input
#   - A dialog launched from within a dialog (font picker)
#
# Run with: ruby preferences_app.rb

require 'wx'

# ─────────────────────────────────────────────────────────────────────────────
# PreferencesDialog
# ─────────────────────────────────────────────────────────────────────────────

class PreferencesDialog < Wx::Dialog
  attr_reader :prefs

  def initialize(parent, prefs)
    super(parent, title: 'Preferences', style: Wx::DEFAULT_DIALOG_STYLE | Wx::RESIZE_BORDER)

    @prefs = prefs
    @dirty = false

    build_ui
    bind_events

    set_size([520, 440])
    centre
  end

  private

  # ── UI construction ────────────────────────────────────────────────────────

  def build_ui
    panel     = Wx::Panel.new(self)
    @notebook = Wx::Notebook.new(panel)

    build_general_page
    build_appearance_page
    build_network_page
    build_advanced_page

    @ok_btn     = Wx::Button.new(panel, id: Wx::ID_OK,     label: 'OK')
    @cancel_btn = Wx::Button.new(panel, id: Wx::ID_CANCEL, label: 'Cancel')
    @apply_btn  = Wx::Button.new(panel, id: Wx::ID_APPLY,  label: 'Apply')
    @apply_btn.enable(false)
    @ok_btn.set_default

    btn_row = Wx::HBoxSizer.new
    btn_row.add_stretch_spacer(1)
    btn_row.add(@cancel_btn, 0, Wx::RIGHT, 8)
    btn_row.add(@apply_btn,  0, Wx::RIGHT, 8)
    btn_row.add(@ok_btn,     0)

    outer = Wx::VBoxSizer.new
    outer.add(@notebook, 1, Wx::EXPAND | Wx::ALL, 12)
    outer.add(btn_row,   0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 12)
    panel.set_sizer(outer)
  end

  def build_general_page
    page = Wx::Panel.new(@notebook)

    user_label  = Wx::StaticText.new(page, label: 'Username:')
    @user_field = Wx::TextCtrl.new(page, value: @prefs[:username])

    @auto_save_cb   = Wx::CheckBox.new(page, label: 'Auto-save every')
    @auto_save_cb.value = @prefs[:auto_save]

    @auto_save_spin = Wx::SpinCtrl.new(page, min: 1, max: 60)
    @auto_save_spin.value = @prefs[:auto_save_mins]
    mins_label = Wx::StaticText.new(page, label: 'minutes')

    @start_max_cb = Wx::CheckBox.new(page, label: 'Start maximised')
    @start_max_cb.value = @prefs[:start_maximised]

    auto_row = Wx::HBoxSizer.new
    auto_row.add(@auto_save_cb,   0, Wx::ALIGN_CENTER_VERTICAL | Wx::RIGHT, 6)
    auto_row.add(@auto_save_spin, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::RIGHT, 6)
    auto_row.add(mins_label,      0, Wx::ALIGN_CENTER_VERTICAL)

    grid = Wx::FlexGridSizer.new(0, 2, 10, 12)
    grid.add_growable_col(1)
    grid.add(user_label,   0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(@user_field,  1, Wx::EXPAND)
    grid.add(Wx::StaticText.new(page, label: ''), 0)
    grid.add(auto_row,     0)
    grid.add(Wx::StaticText.new(page, label: ''), 0)
    grid.add(@start_max_cb, 0)

    outer = Wx::VBoxSizer.new
    outer.add(grid, 1, Wx::EXPAND | Wx::ALL, 12)
    page.set_sizer(outer)

    @notebook.add_page(page, 'General')

    evt_text(@user_field.id)         { mark_dirty }
    evt_checkbox(@auto_save_cb.id)   { mark_dirty }
    evt_spinctrl(@auto_save_spin.id) { mark_dirty }
    evt_checkbox(@start_max_cb.id)   { mark_dirty }
  end

  def build_appearance_page
    page = Wx::Panel.new(@notebook)

    theme_label   = Wx::StaticText.new(page, label: 'Theme:')
    @theme_choice = Wx::Choice.new(page, choices: ['System', 'Light', 'Dark'])
    @theme_choice.string_selection = @prefs[:theme]

    font_label = Wx::StaticText.new(page, label: 'UI font:')
    @font_btn  = Wx::Button.new(page, label: @prefs[:font_name])

    density_label   = Wx::StaticText.new(page, label: 'Density:')
    @density_buttons = [
      Wx::RadioButton.new(page, label: 'Compact',     style: Wx::RB_GROUP),
      Wx::RadioButton.new(page, label: 'Normal'),
      Wx::RadioButton.new(page, label: 'Comfortable'),
    ]
    selected = @density_buttons.find { |rb| rb.label == @prefs[:density] }
    selected&.value = true

    density_row = Wx::HBoxSizer.new
    @density_buttons.each { |rb| density_row.add(rb, 0, Wx::RIGHT, 10) }

    grid = Wx::FlexGridSizer.new(0, 2, 10, 12)
    grid.add_growable_col(1)
    grid.add(theme_label,   0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(@theme_choice, 1, Wx::EXPAND)
    grid.add(font_label,    0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(@font_btn,     0)
    grid.add(density_label, 0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(density_row,   0)

    outer = Wx::VBoxSizer.new
    outer.add(grid, 1, Wx::EXPAND | Wx::ALL, 12)
    page.set_sizer(outer)

    @notebook.add_page(page, 'Appearance')

    evt_choice(@theme_choice.id) { mark_dirty }
    @density_buttons.each { |rb| evt_radiobutton(rb.id) { mark_dirty } }

    evt_button(@font_btn.id) do
      data   = Wx::FontData.new
      dialog = Wx::FontDialog.new(self, data)
      if dialog.show_modal == Wx::ID_OK
        font = dialog.font_data.chosen_font
        @prefs[:font_name] = font.face_name
        @font_btn.label    = font.face_name
        mark_dirty
      end
      dialog.destroy
    end
  end

  def build_network_page
    page = Wx::Panel.new(@notebook)

    @proxy_cb = Wx::CheckBox.new(page, label: 'Use proxy server')
    @proxy_cb.value = @prefs[:use_proxy]

    host_label  = Wx::StaticText.new(page, label: 'Host:')
    @proxy_host = Wx::TextCtrl.new(page, value: @prefs[:proxy_host])

    port_label  = Wx::StaticText.new(page, label: 'Port:')
    @proxy_port = Wx::TextCtrl.new(page, value: @prefs[:proxy_port])

    timeout_label = Wx::StaticText.new(page, label: 'Timeout (seconds):')
    @timeout_spin = Wx::SpinCtrl.new(page, min: 5, max: 120)
    @timeout_spin.value = @prefs[:timeout]

    update_proxy_fields

    grid = Wx::FlexGridSizer.new(0, 2, 10, 12)
    grid.add_growable_col(1)
    grid.add(Wx::StaticText.new(page, label: ''), 0)
    grid.add(@proxy_cb,     0)
    grid.add(host_label,    0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(@proxy_host,   1, Wx::EXPAND)
    grid.add(port_label,    0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(@proxy_port,   1, Wx::EXPAND)
    grid.add(timeout_label, 0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(@timeout_spin, 0)

    outer = Wx::VBoxSizer.new
    outer.add(grid, 1, Wx::EXPAND | Wx::ALL, 12)
    page.set_sizer(outer)

    @notebook.add_page(page, 'Network')

    evt_checkbox(@proxy_cb.id) do
      update_proxy_fields
      mark_dirty
    end
    evt_text(@proxy_host.id)       { mark_dirty }
    evt_text(@proxy_port.id)       { mark_dirty }
    evt_spinctrl(@timeout_spin.id) { mark_dirty }
  end

  def build_advanced_page
    page = Wx::Panel.new(@notebook)

    @debug_cb = Wx::CheckBox.new(page, label: 'Enable debug logging')
    @debug_cb.value = @prefs[:debug_logging]

    cache_label = Wx::StaticText.new(page, label: 'Cache size (MB):')
    @cache_spin = Wx::SpinCtrl.new(page, min: 64, max: 2048)
    @cache_spin.value = @prefs[:cache_size]

    reset_btn = Wx::Button.new(page, label: 'Reset all preferences to defaults')

    grid = Wx::FlexGridSizer.new(0, 2, 10, 12)
    grid.add_growable_col(1)
    grid.add(Wx::StaticText.new(page, label: ''), 0)
    grid.add(@debug_cb,   0)
    grid.add(cache_label, 0, Wx::ALIGN_CENTER_VERTICAL)
    grid.add(@cache_spin, 0)

    outer = Wx::VBoxSizer.new
    outer.add(grid,      0, Wx::EXPAND | Wx::ALL, 12)
    outer.add(reset_btn, 0, Wx::LEFT | Wx::BOTTOM, 12)
    page.set_sizer(outer)

    @notebook.add_page(page, 'Advanced')

    evt_checkbox(@debug_cb.id)   { mark_dirty }
    evt_spinctrl(@cache_spin.id) { mark_dirty }

    evt_button(reset_btn.id) do
      result = Wx::message_box(
        'Reset all preferences to their default values?',
        'Reset Preferences',
        Wx::YES_NO | Wx::ICON_QUESTION
      )
      end_modal(Wx::ID_OK) if result == Wx::YES
    end
  end

  # ── Event handlers ─────────────────────────────────────────────────────────

  def bind_events
    evt_button(Wx::ID_OK)    { on_ok }
    evt_button(Wx::ID_CANCEL) { on_cancel }
    evt_button(Wx::ID_APPLY) { on_apply }
  end

  def on_ok
    apply_prefs
    end_modal(Wx::ID_OK)
  end

  def on_cancel
    end_modal(Wx::ID_CANCEL)
  end

  def on_apply
    apply_prefs
    mark_clean
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  def apply_prefs
    @prefs[:username]        = @user_field.value
    @prefs[:auto_save]       = @auto_save_cb.value
    @prefs[:auto_save_mins]  = @auto_save_spin.value
    @prefs[:start_maximised] = @start_max_cb.value
    @prefs[:theme]           = @theme_choice.string_selection
    @prefs[:density]         = @density_buttons.find(&:value)&.label || 'Normal'
    @prefs[:use_proxy]       = @proxy_cb.value
    @prefs[:proxy_host]      = @proxy_host.value
    @prefs[:proxy_port]      = @proxy_port.value
    @prefs[:timeout]         = @timeout_spin.value
    @prefs[:debug_logging]   = @debug_cb.value
    @prefs[:cache_size]      = @cache_spin.value
  end

  def update_proxy_fields
    enabled = @proxy_cb.value
    @proxy_host.enable(enabled)
    @proxy_port.enable(enabled)
  end

  def mark_dirty
    @dirty = true
    @apply_btn.enable(true)
  end

  def mark_clean
    @dirty = false
    @apply_btn.enable(false)
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# PreferencesFrame
# ─────────────────────────────────────────────────────────────────────────────

class PreferencesFrame < Wx::Frame
  def initialize
    super(nil, title: 'Preferences Demo', size: [600, 400])

    @prefs = default_prefs

    build_menu
    build_ui
    bind_events

    layout
    centre
  end

  private

  def default_prefs
    {
      username:        'user',
      auto_save:       true,
      auto_save_mins:  5,
      start_maximised: false,
      theme:           'System',
      font_name:       'System Default',
      density:         'Normal',
      use_proxy:       false,
      proxy_host:      '',
      proxy_port:      '8080',
      timeout:         30,
      debug_logging:   false,
      cache_size:      256,
    }
  end

  def build_menu
    menu_bar  = Wx::MenuBar.new
    file_menu = Wx::Menu.new
    @prefs_id = file_menu.append(Wx::ID_ANY, "&Preferences...\tCtrl+,").id
    file_menu.append_separator
    file_menu.append(Wx::ID_EXIT, "E&xit\tCtrl+Q")
    menu_bar.append(file_menu, "&File")
    set_menu_bar(menu_bar)
  end

  def build_ui
    @panel = Wx::Panel.new(self)

    @prefs_display = Wx::TextCtrl.new(@panel,
      value: prefs_summary,
      style: Wx::TE_MULTILINE | Wx::TE_READONLY)

    sizer = Wx::VBoxSizer.new
    sizer.add(Wx::StaticText.new(@panel, label: 'Current preferences:'),
              0, Wx::ALL, 12)
    sizer.add(@prefs_display, 1, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 12)
    @panel.set_sizer(sizer)
  end

  def bind_events
    evt_close            { |event| on_close(event) }
    evt_menu(@prefs_id)  { on_preferences }
    evt_menu(Wx::ID_EXIT) { close }
  end

  def on_close(event)
    event.skip
  end

  def on_preferences
    dialog = PreferencesDialog.new(self, @prefs.dup)
    if dialog.show_modal == Wx::ID_OK
      @prefs = dialog.prefs
      @prefs_display.value = prefs_summary
    end
    dialog.destroy
  end

  def prefs_summary
    @prefs.map { |k, v| "#{k}: #{v}" }.join("\n")
  end
end

# ─────────────────────────────────────────────────────────────────────────────

Wx::App.run { PreferencesFrame.new.show }