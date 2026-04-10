# bridge_demo_3.rb
#
# Lesson 5.2 — The JavaScript bridge: Demo 3
# Full bidirectional RPC with JsBridge
#
# Same visual layout as Demo 2, but using the JsBridge class.
# The key addition over Demo 2: Ruby can call a JS method and
# receive a response back — true RPC, not just fire-and-forget.
#
# This is demonstrated clearly:
#   - Ruby calls JS reverseText(text) and gets the reversed string back
#   - Ruby displays the response in the sidebar
#
# Also demonstrates the ready pattern:
#   - JS emits 'ready' when the page is fully initialised
#   - Ruby waits for this before doing anything
#
# Run with: ruby bridge_demo_3.rb

require 'wx'
require 'base64'
require 'json'
require_relative 'js_bridge'

# Load the JavaScript client library — the Ruby/JS bridge pair
JS_BRIDGE_CLIENT = Base64.strict_encode64(
  File.read(File.join(__dir__, 'js_bridge_client.js'))
)

PAGE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <!-- js_bridge_client.js loaded as base64 data URI by Ruby -->
    <script src="data:text/javascript;base64,#{JS_BRIDGE_CLIENT}"></script>
    <style>
      body {
        font-family: -apple-system, sans-serif;
        padding: 24px;
        background: #fff8f0;
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
        border: 2px solid #f77f00;
        font-size: 14px;
        min-height: 48px;
        color: #f77f00;
      }
      #from-ruby span { font-weight: bold; }
    </style>
  </head>
  <body>
    <h1>Full RPC with JsBridge</h1>

    <h2>Send a fixed message to Ruby</h2>
    <button class="btn-red"   onclick="emit('alert',  {message: 'Alert from JS!'})">Send Alert</button>
    <button class="btn-green" onclick="emit('status', {message: 'Status OK'})">Send Status</button>
    <button class="btn-blue"  onclick="emit('log',    {message: 'Log entry at ' + new Date().toLocaleTimeString()})">Send Log</button>

    <h2>Send a custom message to Ruby</h2>
    <input id="msg" type="text" placeholder="Type something..." value="Hello from JS!">
    <button class="btn-send" onclick="sendText()">Send to Ruby</button>

    <h2>Messages from Ruby</h2>
    <div id="from-ruby">Nothing received from Ruby yet...</div>

    <script>
      // ── Methods Ruby can call (with responses) ────────────────────────

      // Ruby calls this and gets the reversed text back as a response
      RubyBridge.register('reverseText', function(payload) {
        var reversed = payload.text.split('').reverse().join('');
        return { reversed: reversed, length: payload.text.length };
      });

      // Ruby calls this to display a message on the page
      RubyBridge.register('showMessage', function(payload) {
        document.getElementById('from-ruby').innerHTML =
          '<span>From Ruby:</span> ' + payload.text;
        return { ok: true };
      });

      // ── Events JS emits to Ruby ───────────────────────────────────────
      function emit(action, payload) {
        RubyBridge.emit(action, payload);
      }

      function sendText() {
        var text = document.getElementById('msg').value;
        RubyBridge.emit('custom', { message: text });
      }

      // NOTE: ready is NOT emitted here.
      // Ruby triggers it via run_script after add_script_message_handler.
      // By the time this script runs, the message handler is not yet
      // registered — so any postMessage call here would be silently dropped.
    </script>
  </body>
  </html>
HTML

class Demo3Frame < Wx::Frame
  def initialize
    super(nil, title: 'Bridge Demo 3 — JsBridge Full RPC', size: [900, 560])

    @panel  = Wx::Panel.new(self)
    @bridge = nil
    @ready  = false

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

    # Send to JS — show message
    send_box    = Wx::StaticBox.new(sidebar, label: 'Send to JS (showMessage)')
    @send_field = Wx::TextCtrl.new(send_box, value: 'Hello from Ruby!')
    send_btn    = Wx::Button.new(send_box, label: 'Show on page')

    send_sz = Wx::StaticBoxSizer.new(send_box, Wx::VERTICAL)
    send_sz.add(@send_field, 0, Wx::EXPAND | Wx::ALL, 6)
    send_sz.add(send_btn,    0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 6)

    # Call JS with response — reverseText
    rpc_box     = Wx::StaticBox.new(sidebar, label: 'Call JS and get response (reverseText)')
    @rpc_field  = Wx::TextCtrl.new(rpc_box, value: 'wxRuby3')
    rpc_btn     = Wx::Button.new(rpc_box, label: 'Reverse it!')
    @rpc_result = Wx::StaticText.new(rpc_box, label: 'Response will appear here')

    rpc_sz = Wx::StaticBoxSizer.new(rpc_box, Wx::VERTICAL)
    rpc_sz.add(@rpc_field,  0, Wx::EXPAND | Wx::ALL, 6)
    rpc_sz.add(rpc_btn,     0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 6)
    rpc_sz.add(@rpc_result, 0, Wx::ALL, 6)

    clear_btn = Wx::Button.new(sidebar, label: 'Clear log')

    side_sz = Wx::VBoxSizer.new
    side_sz.add(recv_sz,   1, Wx::EXPAND | Wx::ALL, 8)
    side_sz.add(send_sz,   0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 8)
    side_sz.add(rpc_sz,    0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 8)
    side_sz.add(clear_btn, 0, Wx::ALIGN_RIGHT | Wx::RIGHT | Wx::BOTTOM, 8)
    sidebar.set_sizer(side_sz)

    splitter.split_vertically(wv_panel, sidebar, 540)
    splitter.set_minimum_pane_size(200)

    create_status_bar
    set_status_text('Loading page...')

    outer = Wx::VBoxSizer.new
    outer.add(splitter, 1, Wx::EXPAND | Wx::ALL, 4)
    @panel.set_sizer(outer)
    @panel.layout

    evt_button(send_btn.id)  { on_show_message }
    evt_button(rpc_btn.id)   { on_reverse_text }
    evt_button(clear_btn.id) { @log.clear }
  end

  def bind_events
    @webview.load_url("data:text/html;base64,#{Base64.strict_encode64(PAGE_HTML)}")

    @bridge = JsBridge.new(@webview)

    # Register message handler inside evt_webview_loaded
    @webview.evt_webview_loaded(@webview.id) do
      next if @webview.current_url == 'about:blank'
      @webview.add_script_message_handler('bridge')
      # Trigger ready from Ruby — the JS emit('ready') in the page
      # would fire before the handler is registered and be silently dropped.
      @bridge.run_script("RubyBridge.emit('ready', {})")
    end

    # Dispatch all incoming messages through JsBridge
    @webview.evt_webview_script_message_received(@webview.id) do |event|
      @bridge.dispatch(event.get_string)
    end

    # JS signals it is ready — safe to communicate now
    @bridge.on('ready') do
      @ready = true
      set_status_text('Page ready — try the buttons on both sides')
    end

    # JS events → Ruby log
    %w[alert status log custom].each do |action|
      @bridge.on(action) do |payload|
        message = payload['message'] || '(no message)'
        time    = Time.now.strftime('%H:%M:%S')
        @log.append_text("[#{time}] #{action}: #{message}\n")
        set_status_text("Received: #{action}")
      end
    end

    evt_close { |event| on_close(event) }
  end

  # Ruby → JS: call showMessage, no response needed
  def on_show_message
    return unless @ready
    @bridge.call('showMessage', { text: @send_field.value }) do |_result, error|
      set_status_text(error ? "Error: #{error}" : "Sent message to JS")
    end
  end

  # Ruby → JS: call reverseText, display the response
  def on_reverse_text
    return unless @ready
    text = @rpc_field.value
    @rpc_result.label = 'Waiting for JS response...'

    @bridge.call('reverseText', { text: text }) do |result, error|
      if error
        @rpc_result.label = "Error: #{error}"
        set_status_text("reverseText error: #{error}")
      else
        reversed = result['reversed']
        length   = result['length']
        @rpc_result.label = "Reversed: #{reversed} (#{length} chars)"
        @rpc_field.value = reversed
      end
    end
  end

  def on_close(event)
    event.skip
  end
end

Wx::App.run { Demo3Frame.new.show }