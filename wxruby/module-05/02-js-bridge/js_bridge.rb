# lib/js_bridge.rb
#
# JsBridge — bidirectional Ruby ↔ JavaScript communication for Wx::WEB::WebView
#
# wxRuby3 Desktop Development Tutorial Series — Module 5
#
# Usage:
#
#   require_relative 'lib/js_bridge'
#
#   # In your frame, after creating the WebView:
#   @bridge = JsBridge.new(@webview)
#
#   # Register the message handler inside evt_webview_loaded:
#   evt_webview_loaded(@webview.id) do
#     @webview.add_script_message_handler('bridge')
#     @bridge.run_script("window.ready = true")
#   end
#
#   # Wire up the message receiver:
#   evt_webview_script_message_received(@webview.id) do |event|
#     @bridge.dispatch(event.get_string)
#   end
#
#   # Listen for events from JS:
#   @bridge.on('mapClick') { |payload| handle_click(payload) }
#
#   # Call a JS method and get a callback when it responds:
#   @bridge.call('getStats', { series: 'temperature' }) do |result, error|
#     puts result['mean'] unless error
#   end
#
#   # Emit an event to JS (fire and forget):
#   @bridge.emit('dataUpdate', { value: 42 })
#
# The JavaScript side must include the RubyBridge object — see
# js_bridge_client.js for the client-side implementation.
#
# IMPORTANT: add_script_message_handler MUST be called inside
# evt_webview_loaded, not during frame initialisation. Calling it
# too early results in the handler not being registered.
#
# IMPORTANT: The ready pattern. Never rely on JS emitting 'ready'
# automatically at the end of the page script. By the time
# evt_webview_loaded fires, the page script has already executed —
# the message handler was not yet registered, so the message is
# silently dropped. Instead, Ruby triggers ready manually after
# registering the handler:
#
#   @webview.evt_webview_loaded(@webview.id) do
#     next if @webview.current_url == 'about:blank'
#     @webview.add_script_message_handler('bridge')
#     @bridge.run_script("RubyBridge.emit('ready', {})")
#   end

require 'json'

class JsBridge
  # How long to wait for a JS response before calling back with 'timeout'
  DEFAULT_TIMEOUT = 10

  def initialize(webview)
    @webview  = webview
    @pending  = {}   # pending call callbacks, keyed by request id
    @handlers = {}   # event handlers registered with on()
    @seq      = 0    # sequence counter for request ids
  end

  # Register a handler for events emitted by JavaScript.
  # Multiple handlers can be registered for the same event.
  #
  #   @bridge.on('markerClicked') { |payload| ... }
  def on(event, &block)
    @handlers[event.to_s] ||= []
    @handlers[event.to_s] << block
    self
  end

  # Call a JavaScript method and receive the result via callback.
  # The callback receives (result, error) — error is nil on success.
  #
  #   @bridge.call('getStats', { series: 'temp' }) do |result, error|
  #     label.value = error ? "Error: #{error}" : result['mean'].to_s
  #   end
  def call(method, payload = {}, timeout: DEFAULT_TIMEOUT, &callback)
    id  = next_id
    msg = JSON.generate({ id: id, type: 'call', method: method, payload: payload })
    @pending[id] = { callback: callback, expires_at: Time.now + timeout }
    run_script("window.RubyBridge.receive(#{msg})")
    id
  end

  # Emit an event to JavaScript — fire and forget, no response expected.
  #
  #   @bridge.emit('themeChanged', { theme: 'dark' })
  def emit(event, payload = {})
    msg = JSON.generate({ type: 'event', event: event, payload: payload })
    run_script("window.RubyBridge.receive(#{msg})")
  end

  # Execute JavaScript directly on the WebView.
  # Errors are suppressed — the WebView logs them internally.
  # Use for one-off commands that don't need a response.
  #
  #   @bridge.run_script("document.body.style.background = 'red'")
  def run_script(js)
    old_level = Wx::Log.get_log_level
    Wx::Log.set_log_level(0)
    @webview.run_script(js)
    Wx::Log.set_log_level(old_level)
  rescue
    Wx::Log.set_log_level(old_level) rescue nil
  end

  # Dispatch a raw JSON message received from JavaScript.
  # Called from evt_webview_script_message_received.
  #
  #   evt_webview_script_message_received(@webview.id) do |event|
  #     @bridge.dispatch(event.get_string)
  #   end
  def dispatch(raw)
    data = JSON.parse(raw)
    case data['type']
    when 'response' then handle_response(data)
    when 'event'    then handle_event(data)
    end
  rescue JSON::ParserError => e
    $stderr.puts "JsBridge: malformed JSON: #{e.message}"
  end

  # Expire pending calls that have exceeded their timeout.
  # Call this from a periodic timer (e.g. every 1000ms):
  #
  #   @expire_timer = Wx::Timer.new(self)
  #   evt_timer(@expire_timer.id) { @bridge.expire_pending }
  #   @expire_timer.start(1000)
  def expire_pending
    now = Time.now
    @pending.select { |_, entry| now > entry[:expires_at] }.each do |id, entry|
      entry[:callback]&.call(nil, 'timeout')
      @pending.delete(id)
    end
  end

  private

  def handle_response(data)
    entry = @pending.delete(data['id'])
    entry[:callback]&.call(data['payload'], data['error']) if entry
  end

  def handle_event(data)
    (@handlers[data['event'].to_s] || []).each do |handler|
      handler.call(data['payload'])
    end
  end

  def next_id
    "req_#{@seq += 1}"
  end
end