/**
 * js_bridge_client.js
 *
 * Client-side JavaScript for the JsBridge Ruby↔JS communication layer.
 * wxRuby3 Desktop Development Tutorial Series — Module 5
 *
 * Include this in your WebView HTML, either:
 *   a) Inline in a <script> tag (copy-paste into your heredoc)
 *   b) As a local file loaded via base64 data URI
 *   c) Served from a local HTTP server
 *
 * Usage in HTML:
 *
 *   // Register methods callable from Ruby:
 *   RubyBridge.register('pushData', function(payload) {
 *     updateChart(payload.value);
 *     return { ok: true };  // returned to Ruby callback
 *   });
 *
 *   // Listen for events from Ruby:
 *   RubyBridge.on('themeChanged', function(payload) {
 *     applyTheme(payload.theme);
 *   });
 *
 *   // Emit an event to Ruby (fire and forget):
 *   RubyBridge.emit('markerClicked', { lat: 51.5, lng: -0.1 });
 *
 *   // Signal Ruby that the page is ready:
 *   RubyBridge.emit('ready', {});
 *
 * IMPORTANT: The 'ready' event pattern is essential. Ruby must not
 * call bridge methods until the page has fully loaded and the
 * RubyBridge object is available. Always emit 'ready' at the end
 * of your page initialisation, and have Ruby start its work in
 * the @bridge.on('ready') handler.
 */

window.RubyBridge = (function() {
    'use strict';

    var registeredMethods = {};
    var eventHandlers     = {};

    /**
     * Register a method that Ruby can call via @bridge.call(name, payload).
     * The function receives the payload and may return a value synchronously
     * or return a Promise for async operations.
     */
    function register(name, fn) {
        registeredMethods[name] = fn;
    }

    /**
     * Register a handler for events emitted by Ruby via @bridge.emit(event, payload).
     * Multiple handlers can be registered for the same event.
     */
    function on(event, fn) {
        eventHandlers[event] = eventHandlers[event] || [];
        eventHandlers[event].push(fn);
    }

    /**
     * Emit an event to Ruby. Ruby must have registered a handler with
     * @bridge.on('eventName') { |payload| ... }
     */
    function emit(event, payload) {
        notifyRuby({ type: 'event', event: event, payload: payload || {} });
    }

    /**
     * Internal: send a response back to a Ruby @bridge.call() invocation.
     */
    function respond(id, payload, error) {
        notifyRuby({ id: id, type: 'response', payload: payload, error: error || null });
    }

    /**
     * Internal: called by Ruby's JsBridge#call and JsBridge#emit.
     * Routes incoming messages to registered methods or event handlers.
     */
    function receive(msg) {
        if (msg.type === 'call') {
            var fn = registeredMethods[msg.method];
            if (!fn) {
                respond(msg.id, null, 'Unknown method: ' + msg.method);
                return;
            }
            try {
                var result = fn(msg.payload);
                // Support async methods that return a Promise
                if (result && typeof result.then === 'function') {
                    result.then(
                        function(v) { respond(msg.id, v, null); },
                        function(e) { respond(msg.id, null, e.message || String(e)); }
                    );
                } else {
                    respond(msg.id, result !== undefined ? result : null, null);
                }
            } catch (e) {
                respond(msg.id, null, e.message || String(e));
            }

        } else if (msg.type === 'event') {
            var handlers = eventHandlers[msg.event] || [];
            handlers.forEach(function(fn) {
                try { fn(msg.payload); } catch (e) {
                    console.error('RubyBridge event handler error:', e);
                }
            });
        }
    }

    /**
     * Internal: post a message to the Ruby WebKit message handler.
     * The handler name 'bridge' must match add_script_message_handler('bridge').
     */
    function notifyRuby(data) {
        window.webkit.messageHandlers.bridge.postMessage(JSON.stringify(data));
    }

    return {
        register: register,
        on:       on,
        emit:     emit,
        receive:  receive
    };

})();