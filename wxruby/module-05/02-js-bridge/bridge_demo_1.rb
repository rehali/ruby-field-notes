# bridge_demo_1.rb
#
# Lesson 5.2 — The JavaScript bridge: Demo 1
# Navigation Interception (JS → Ruby only)
#
# The WebView page has buttons and a text field.
# Clicking a button sets window.location to a custom bridge:// URL.
# Ruby intercepts the navigation, cancels it, and updates the sidebar.
#
# This is the simplest bridge pattern — no setup required.
# Limitation: one direction only (JS → Ruby).
#
# Run with: ruby bridge_demo_1.rb

require 'wx'
require 'base64'
require 'json'
require 'uri'

PAGE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <style>
      body {
        font-family: -apple-system, sans-serif;
        padding: 24px;
        background: #f8f9fa;
        color: #212529;
      }
      h2 { font-size: 14px; color: #6c757d; text-transform: uppercase;
           letter-spacing: 0.05em; margin: 20px 0 8px; }
      button {
        padding: 10px 18px;
        margin: 4px;
        border: none;
        border-radius: 6px;
        cursor: pointer;
        font-size: 14px;
        color: white;
      }
      .btn-red    { background: #e63946; }
      .btn-green  { background: #2a9d8f; }
      .btn-blue   { background: #264653; }
      .btn-send   { background: #6a4c93; }
      input[type=text] {
        padding: 8px 12px;
        border: 1px solid #ced4da;
        border-radius: 6px;
        font-size: 14px;
        width: 220px;
        margin-right: 6px;
      }
    </style>
  </head>
  <body>
    <h1>JS → Ruby via Navigation Interception</h1>

    <h2>Send a fixed message</h2>
    <button class="btn-red"   onclick="send('alert',   {message: 'Alert from JS!'})">Send Alert</button>
    <button class="btn-green" onclick="send('status',  {message: 'Status OK'})">Send Status</button>
    <button class="btn-blue"  onclick="send('log',     {message: 'Log entry at ' + new Date().toLocaleTimeString()})">Send Log</button>

    <h2>Send a custom message</h2>
    <input id="msg" type="text" placeholder="Type something..." value="Hello from JS!">
    <button class="btn-send" onclick="sendText()">Send to Ruby</button>

    <script>
      // Navigate to a custom URL scheme.
      // Ruby intercepts this in evt_webview_navigating and cancels it.
      // The action and payload are encoded in the URL.
      function send(action, payload) {
        var data = encodeURIComponent(JSON.stringify(payload));
        window.location = 'bridge://' + action + '?data=' + data;
      }

      function sendText() {
        var text = document.getElementById('msg').value;
        send('custom', { message: text });
      }
    </script>
  </body>
  </html>
HTML

class Demo1Frame < Wx::Frame
  def initialize
    super(nil, title: 'Bridge Demo 1 — Navigation Interception', size: [900, 480])

    @panel = Wx::Panel.new(self)
    build_ui
    bind_events

    layout
    centre
  end

  private

  def build_ui
    splitter = Wx::SplitterWindow.new(@panel, style: Wx::SP_3DSASH | Wx::SP_LIVE_UPDATE)

    # ── Left: WebView ─────────────────────────────────────────────────────
    wv_panel  = Wx::Panel.new(splitter)
    @webview  = Wx::WEB::WebView.new(wv_panel, Wx::ID_ANY, 'about:blank')
    wv_sizer  = Wx::VBoxSizer.new
    wv_sizer.add(@webview, 1, Wx::EXPAND)
    wv_panel.set_sizer(wv_sizer)

    # ── Right: Ruby sidebar ───────────────────────────────────────────────
    sidebar = Wx::Panel.new(splitter)

    recv_box = Wx::StaticBox.new(sidebar, label: 'Messages received from JS')
    @log     = Wx::TextCtrl.new(recv_box, value: '',
                                style: Wx::TE_MULTILINE | Wx::TE_READONLY)

    recv_sz = Wx::StaticBoxSizer.new(recv_box, Wx::VERTICAL)
    recv_sz.add(@log, 1, Wx::EXPAND | Wx::ALL, 6)

    clear_btn = Wx::Button.new(sidebar, label: 'Clear log')

    side_sz = Wx::VBoxSizer.new
    side_sz.add(recv_sz,   1, Wx::EXPAND | Wx::ALL, 8)
    side_sz.add(clear_btn, 0, Wx::ALIGN_RIGHT | Wx::RIGHT | Wx::BOTTOM, 8)
    sidebar.set_sizer(side_sz)

    splitter.split_vertically(wv_panel, sidebar, 580)
    splitter.set_minimum_pane_size(200)

    create_status_bar
    set_status_text('Click a button in the page — Ruby will receive the message')

    outer = Wx::VBoxSizer.new
    outer.add(splitter, 1, Wx::EXPAND | Wx::ALL, 4)
    @panel.set_sizer(outer)
    @panel.layout

    evt_button(clear_btn.id) { @log.clear }
  end

  def bind_events
    # Load the page
    @webview.load_url("data:text/html;base64,#{Base64.strict_encode64(PAGE_HTML)}")

    # Intercept any navigation to bridge:// URLs
    @webview.evt_webview_navigating(@webview.id) do |event|
      url = event.url
      next unless url.start_with?('bridge://')

      # Cancel the navigation — we handle it ourselves
      event.veto

      # Parse action and payload from the URL
      uri    = URI.parse(url) rescue next
      action = uri.host
      params = URI.decode_www_form(uri.query || '').to_h
      data   = JSON.parse(URI.decode_www_form_component(params['data'] || '{}')) rescue {}

      on_bridge_message(action, data)
    end

    evt_close { |event| on_close(event) }
  end

  def on_bridge_message(action, data)
    message = data['message'] || '(no message)'
    time    = Time.now.strftime('%H:%M:%S')

    log_line = "[#{time}] #{action}: #{message}"
    @log.append_text("#{log_line}\n")
    set_status_text("Received: #{action}")
  end

  def on_close(event)
    event.skip
  end
end

Wx::App.run { Demo1Frame.new.show }