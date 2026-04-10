# bridge_demo_2.rb
#
# Lesson 5.2 — The JavaScript bridge: Demo 2
# Script Message Handler (JS ↔ Ruby via run_script)
#
# Same concept as Demo 1 but using WebKit's native message handler.
# Adds Ruby → JS: a text field and button in the Ruby sidebar
# sends text back to the page for display.
#
# Key points:
#   - add_script_message_handler MUST be called inside evt_webview_loaded
#   - JS posts JSON via window.webkit.messageHandlers.bridge.postMessage
#   - Ruby responds with run_script to call a JS function directly
#
# Run with: ruby bridge_demo_2.rb

require 'wx'
require 'base64'
require 'json'

PAGE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <style>
      body {
        font-family: -apple-system, sans-serif;
        padding: 24px;
        background: #f0f4ff;
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
      #from-ruby {
        margin-top: 24px;
        padding: 14px 16px;
        background: white;
        border-radius: 8px;
        border: 2px solid #6a4c93;
        font-size: 14px;
        min-height: 48px;
        color: #6a4c93;
      }
      #from-ruby span { font-weight: bold; }
    </style>
  </head>
  <body>
    <h1>JS ↔ Ruby via Script Message Handler</h1>

    <h2>Send a fixed message to Ruby</h2>
    <button class="btn-red"   onclick="send('alert',  {message: 'Alert from JS!'})">Send Alert</button>
    <button class="btn-green" onclick="send('status', {message: 'Status OK'})">Send Status</button>
    <button class="btn-blue"  onclick="send('log',    {message: 'Log entry at ' + new Date().toLocaleTimeString()})">Send Log</button>

    <h2>Send a custom message to Ruby</h2>
    <input id="msg" type="text" placeholder="Type something..." value="Hello from JS!">
    <button class="btn-send" onclick="sendText()">Send to Ruby</button>

    <h2>Messages from Ruby</h2>
    <div id="from-ruby">Nothing received from Ruby yet...</div>

    <script>
      // Post a JSON message to the named Ruby handler.
      // Ruby receives this in evt_webview_script_message_received.
      function send(action, payload) {
        window.webkit.messageHandlers.bridge.postMessage(
          JSON.stringify({ action: action, payload: payload })
        );
      }

      function sendText() {
        var text = document.getElementById('msg').value;
        send('custom', { message: text });
      }

      // Ruby calls this via run_script to display a message on the page.
      // This is the Ruby → JS direction.
      function receiveFromRuby(text) {
        document.getElementById('from-ruby').innerHTML =
          '<span>From Ruby:</span> ' + text;
      }
    </script>
  </body>
  </html>
HTML

class Demo2Frame < Wx::Frame
  def initialize
    super(nil, title: 'Bridge Demo 2 — Script Message Handler', size: [900, 520])

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
    wv_panel = Wx::Panel.new(splitter)
    @webview = Wx::WEB::WebView.new(wv_panel, Wx::ID_ANY, 'about:blank')
    wv_sizer = Wx::VBoxSizer.new
    wv_sizer.add(@webview, 1, Wx::EXPAND)
    wv_panel.set_sizer(wv_sizer)

    # ── Right: Ruby sidebar ───────────────────────────────────────────────
    sidebar = Wx::Panel.new(splitter)

    # Received from JS
    recv_box = Wx::StaticBox.new(sidebar, label: 'Received from JS')
    @log     = Wx::TextCtrl.new(recv_box, value: '',
                                style: Wx::TE_MULTILINE | Wx::TE_READONLY)
    recv_sz  = Wx::StaticBoxSizer.new(recv_box, Wx::VERTICAL)
    recv_sz.add(@log, 1, Wx::EXPAND | Wx::ALL, 6)

    # Send to JS
    send_box   = Wx::StaticBox.new(sidebar, label: 'Send to JS')
    @send_field = Wx::TextCtrl.new(send_box, value: 'Hello from Ruby!')
    send_btn    = Wx::Button.new(send_box, label: 'Send to page')

    send_sz = Wx::StaticBoxSizer.new(send_box, Wx::VERTICAL)
    send_sz.add(@send_field, 0, Wx::EXPAND | Wx::ALL, 6)
    send_sz.add(send_btn,    0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 6)

    clear_btn = Wx::Button.new(sidebar, label: 'Clear log')

    side_sz = Wx::VBoxSizer.new
    side_sz.add(recv_sz,   1, Wx::EXPAND | Wx::ALL, 8)
    side_sz.add(send_sz,   0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 8)
    side_sz.add(clear_btn, 0, Wx::ALIGN_RIGHT | Wx::RIGHT | Wx::BOTTOM, 8)
    sidebar.set_sizer(side_sz)

    splitter.split_vertically(wv_panel, sidebar, 560)
    splitter.set_minimum_pane_size(200)

    create_status_bar
    set_status_text('Click a button in the page — Ruby will receive the message')

    outer = Wx::VBoxSizer.new
    outer.add(splitter, 1, Wx::EXPAND | Wx::ALL, 4)
    @panel.set_sizer(outer)
    @panel.layout

    evt_button(send_btn.id)  { on_send_to_js }
    evt_button(clear_btn.id) { @log.clear }
  end

  def bind_events
    @webview.load_url("data:text/html;base64,#{Base64.strict_encode64(PAGE_HTML)}")

    # CRITICAL: add_script_message_handler must be called inside
    # evt_webview_loaded — not during frame initialisation.
    @webview.evt_webview_loaded(@webview.id) do
      next if @webview.current_url == 'about:blank'
      @webview.add_script_message_handler('bridge')
      set_status_text('Page loaded — message handler registered')
    end

    # Receive messages from JS
    @webview.evt_webview_script_message_received(@webview.id) do |event|
      data   = JSON.parse(event.get_string)
      action  = data['action']
      message = data.dig('payload', 'message') || '(no message)'
      time    = Time.now.strftime('%H:%M:%S')
      @log.append_text("[#{time}] #{action}: #{message}\n")
      set_status_text("Received: #{action}")
    end

    evt_close { |event| on_close(event) }
  end

  # Ruby → JS: call receiveFromRuby() on the page via run_script
  def on_send_to_js
    text = @send_field.value.gsub("'", "\\'")
    @webview.run_script("receiveFromRuby('#{text}')")
    set_status_text("Sent to JS: #{@send_field.value}")
  end

  def on_close(event)
    event.skip
  end
end

Wx::App.run { Demo2Frame.new.show }