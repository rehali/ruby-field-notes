# webview_demo.rb
#
# Lesson 5.1 — WebView basics
# wxRuby3 Desktop Development Tutorial Series
#
# Demonstrates three approaches to loading content into a WebView:
#   1. Inline HTML string via set_page
#   2. CDN-hosted library (Chart.js) via script tag
#   3. Base64 data URI via load_url (the reliable cross-platform approach)
#
# Also demonstrates:
#   - WebView events (loaded, error, title_changed)
#   - run_script for Ruby→JS communication
#   - The markdown editor upgraded from HtmlWindow to WebView
#
# Run with: ruby webview_demo.rb
#
# Note: requires internet access for the CDN demo tab.

require 'wx'
require 'base64'
require 'json'

# ── Approach 1: Inline HTML string ───────────────────────────────────────────
#
# set_page(html, base_url) loads an HTML string directly.
# The base_url is usually '' for inline content.
# Good for: simple self-contained pages, no external resources needed.

INLINE_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <style>
      body { font-family: -apple-system, sans-serif; padding: 24px;
             background: #f8f9fa; color: #212529; }
      h1   { color: #0d6efd; }
      code { background: #e9ecef; padding: 2px 6px; border-radius: 3px; }
      pre  { background: #212529; color: #f8f9fa; padding: 16px;
             border-radius: 6px; font-size: 13px; }
    </style>
  </head>
  <body>
    <h1>Approach 1: Inline HTML</h1>
    <p>This page was loaded with <code>set_page(html, '')</code>.</p>
    <p>The HTML is defined as a Ruby heredoc and passed directly to the WebView.
       No files are needed — everything is self-contained in the Ruby source.</p>
    <h2>When to use this</h2>
    <ul>
      <li>Simple, self-contained pages</li>
      <li>No large external libraries needed</li>
      <li>Content generated dynamically from Ruby data</li>
    </ul>
    <h2>The Ruby code</h2>
    <pre>@webview.set_page(html_string, '')</pre>
    <p>Full CSS is supported. JavaScript works. External resources
       (images, fonts) require a base URL or data URIs.</p>
    <h2>WebView vs HtmlWindow</h2>
    <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; width: 100%;">
      <thead style="background: #0d6efd; color: white;">
        <tr>
          <th style="text-align: left;">Feature</th>
          <th style="text-align: center;">HtmlWindow</th>
          <th style="text-align: center;">WebView</th>
        </tr>
      </thead>
      <tbody>
        <tr><td>Basic HTML</td><td style="text-align:center;">✓</td><td style="text-align:center;">✓</td></tr>
        <tr style="background:#f8f9fa;"><td>CSS stylesheets</td><td style="text-align:center;">Limited</td><td style="text-align:center;">✓ Full</td></tr>
        <tr><td>JavaScript</td><td style="text-align:center;">✗</td><td style="text-align:center;">✓</td></tr>
        <tr style="background:#f8f9fa;"><td>Syntax highlighting</td><td style="text-align:center;">✗</td><td style="text-align:center;">✓</td></tr>
        <tr><td>External libraries (CDN)</td><td style="text-align:center;">✗</td><td style="text-align:center;">✓</td></tr>
        <tr style="background:#f8f9fa;"><td>Ruby↔JS bridge</td><td style="text-align:center;">✗</td><td style="text-align:center;">✓</td></tr>
        <tr><td>Setup complexity</td><td style="text-align:center;">None</td><td style="text-align:center;">Low</td></tr>
      </tbody>
    </table>
  </body>
  </html>
HTML

# ── Approach 2: CDN-hosted library ───────────────────────────────────────────
#
# Include third-party libraries via CDN script tags.
# The WebView fetches them over the network at page load time.
# Good for: any library where network access is available.
# Not suitable for: offline use, or when you need a specific bundled version.

CDN_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
      body { font-family: -apple-system, sans-serif; padding: 24px;
             background: #1a1a2e; color: #eee; }
      h1   { color: #e94560; }
      code { background: #16213e; padding: 2px 6px; border-radius: 3px; }
      .chart-box { background: #16213e; border-radius: 8px; padding: 16px;
                   max-width: 500px; margin: 20px 0; }
    </style>
  </head>
  <body>
    <h1>Approach 2: CDN Library</h1>
    <p>Chart.js was loaded from a CDN — no local file needed.</p>
    <div class="chart-box">
      <canvas id="chart" height="200"></canvas>
    </div>
    <script>
      var ctx = document.getElementById('chart').getContext('2d');
      new Chart(ctx, {
        type: 'bar',
        data: {
          labels: ['Jan','Feb','Mar','Apr','May','Jun'],
          datasets: [{
            label: 'Sales',
            data: [42, 78, 55, 91, 63, 87],
            backgroundColor: '#e94560cc'
          }]
        },
        options: {
          responsive: true,
          plugins: { legend: { labels: { color: '#eee' } } },
          scales: {
            x: { ticks: { color: '#aaa' }, grid: { color: '#333' } },
            y: { ticks: { color: '#aaa' }, grid: { color: '#333' } }
          }
        }
      });
    </script>
  </body>
  </html>
HTML

# ── Approach 3: Base64 data URI ───────────────────────────────────────────────
#
# Encode the complete HTML page as base64 and load via load_url.
# This is the most reliable cross-platform approach for complex pages.
#
# Why? set_page has known issues with some WebKit versions — inline scripts
# may not execute reliably. load_url("data:text/html;base64,...") works
# consistently across all platforms and WebView backends.
#
# Good for: any page where set_page causes issues, or as a default approach.

BASE64_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <style>
      body { font-family: -apple-system, sans-serif; padding: 24px;
             background: #f0fdf4; color: #14532d; }
      h1   { color: #16a34a; }
      code { background: #dcfce7; padding: 2px 6px; border-radius: 3px;
             color: #15803d; }
      pre  { background: #14532d; color: #f0fdf4; padding: 16px;
             border-radius: 6px; }
    </style>
  </head>
  <body>
    <h1>Approach 3: Base64 Data URI</h1>
    <p>This page was loaded with
       <code>load_url("data:text/html;base64,#{'{'}encoded{'}'}")</code>.</p>
    <p>The HTML is base64-encoded in Ruby and passed as a data URI.
       This is the most reliable approach — scripts always execute,
       and it works identically on macOS, Windows, and Linux.</p>
    <h2>When to use this</h2>
    <ul>
      <li>When <code>set_page</code> causes script execution issues</li>
      <li>As a safe default for any dynamic content page</li>
      <li>When you need guaranteed script execution</li>
    </ul>
    <h2>The Ruby code</h2>
    <pre>encoded = Base64.strict_encode64(html)
@webview.load_url("data:text/html;base64,\#{encoded}")</pre>
    <script>
      // This script executes reliably with base64 load_url
      document.title = 'Base64 Demo — Loaded!';
    </script>

  </body>
  </html>
HTML

# ── WebView demo frame ─────────────────────────────────────────────────────────

class WebViewDemoFrame < Wx::Frame
  def initialize
    super(nil, title: 'WebView Demo', size: [900, 600])

    @panel = Wx::Panel.new(self)
    build_ui
    bind_events

    layout
    centre
  end

  private

  def build_ui
    # Tab selector
    @tabs = Wx::Notebook.new(@panel)

    # ── Tab 1: Inline HTML ────────────────────────────────────────────────
    @wv1 = make_webview(@tabs)
    @tabs.add_page(make_page(@tabs, @wv1), 'Inline HTML')

    # ── Tab 2: CDN library ────────────────────────────────────────────────
    @wv2 = make_webview(@tabs)
    @tabs.add_page(make_page(@tabs, @wv2), 'CDN Library')

    # ── Tab 3: Base64 data URI ────────────────────────────────────────────
    @wv3 = make_webview(@tabs)
    @tabs.add_page(make_page(@tabs, @wv3), 'Base64 URI')

    # ── run_script demo panel ─────────────────────────────────────────────
    ctrl_box   = Wx::StaticBox.new(@panel, label: 'run_script demo (Tab 1)')
    @js_input  = Wx::TextCtrl.new(ctrl_box, value: "document.querySelector('h1').style.color = 'red'")
    @run_btn   = Wx::Button.new(ctrl_box, label: 'Run JS')

    ctrl_row = Wx::HBoxSizer.new
    ctrl_row.add(@js_input, 1, Wx::EXPAND | Wx::RIGHT, 6)
    ctrl_row.add(@run_btn, 0)

    ctrl_sz = Wx::StaticBoxSizer.new(ctrl_box, Wx::VERTICAL)
    ctrl_sz.add(ctrl_row, 0, Wx::EXPAND | Wx::ALL, 8)

    create_status_bar
    set_status_text('Select a tab to see each loading approach')

    sizer = Wx::VBoxSizer.new
    sizer.add(@tabs,    1, Wx::EXPAND | Wx::ALL, 4)
    sizer.add(ctrl_sz,  0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 4)
    @panel.set_sizer(sizer)
    @panel.layout
  end

  def make_webview(parent)
    Wx::WEB::WebView.new(parent, Wx::ID_ANY, 'about:blank')
  end

  def make_page(parent, webview)
    page  = Wx::Panel.new(parent)
    sizer = Wx::VBoxSizer.new
    webview.reparent(page)
    sizer.add(webview, 1, Wx::EXPAND)
    page.set_sizer(sizer)
    page
  end

  def bind_events
    # ── Load content into each WebView ────────────────────────────────────

    # Approach 1: set_page with inline HTML string
    @wv1.evt_webview_loaded(@wv1.id) do
      next if @wv1.current_url == 'about:blank'
      set_status_text('Tab 1 loaded via set_page')
    end
    @wv1.set_page(INLINE_HTML, '')

    # Approach 2: set_page with CDN library — note we wait for loaded
    # event before declaring success, since CDN fetch takes a moment
    @wv2.evt_webview_loaded(@wv2.id) do
      next if @wv2.current_url == 'about:blank'
      set_status_text('Tab 2 loaded via set_page + CDN')
    end
    @wv2.evt_webview_error(@wv2.id) do |event|
      set_status_text("Tab 2 error: #{event.string}")
    end
    @wv2.set_page(CDN_HTML, '')

    # Approach 3: load_url with base64 data URI
    @wv3.evt_webview_loaded(@wv3.id) do
      next if @wv3.current_url == 'about:blank'
      set_status_text('Tab 3 loaded via load_url + base64')
    end
    encoded = Base64.strict_encode64(BASE64_HTML)
    @wv3.load_url("data:text/html;base64,#{encoded}")

    # ── Notebook tab change ────────────────────────────────────────────────
    evt_notebook_page_changed(@tabs.id) do
      tab = @tabs.selection
      hints = ['set_page(html, \'\')',
               'set_page(html_with_cdn, \'\')',
               'load_url("data:text/html;base64,...")']
      set_status_text("Approach: #{hints[tab]}")
    end

    # ── run_script demo ───────────────────────────────────────────────────
    # run_script executes JavaScript in the WebView and returns the result.
    # It operates on whichever WebView is currently visible (Tab 1 here).
    evt_button(@run_btn.id) do
      js = @js_input.value.strip
      next if js.empty?
      begin
        result = @wv1.run_script(js)
        set_status_text("run_script result: #{result.inspect}")
      rescue => e
        set_status_text("run_script error: #{e.message}")
      end
    end

    evt_close { |event| on_close(event) }
  end

  def on_close(event)
    event.skip
  end
end

Wx::App.run { WebViewDemoFrame.new.show }