# app/views/components/charts/stock_candlestick.rb
#
# Candlestick chart showing OHLCV data for simulated stocks.
#
# Requires an extended StockFeed that accumulates ticks into OHLCV candles.
# See Stats::StockCandles service below.
#
# Wire up:
#   def stock_candlestick
#     @data = Stats::StockCandles.call(symbol: params[:symbol] || "MIN")
#   end
#
# Stats::StockCandles — build this service to aggregate StockFeed ticks:
#   {
#     symbol:     "MIN",
#     timestamps: ["09:00", "09:01", ...],
#     candles:    [[open, close, low, high], ...]  # note ECharts order
#   }

module Components
  module Charts
    class StockCandlestick < Components::Chart
      prop :data, _Any, default: -> { {} }

      private

      def chart_options
        ::Chart::Options.new(
          # Down candle, up candle
          color:   %w[#ef4444 #22c55e],
          tooltip: {
            trigger:   "axis",
            formatter: "ohlcv"   # add to custom_chart_formatters.js
          },
          legend:  { show: false },
          x_axis:  {
            type: "category",
            data: @data[:timestamps] || [],
            axisLabel: { interval: 9 }
          },
          y_axis:  {
            type:  "value",
            scale: true    # essential — do not start at zero
          },
          grid:    { left: 8, right: 8, bottom: 40, containLabel: true },
          series: [
            {
              type: "candlestick",
              name: @data[:symbol],
              # ECharts candlestick data order: [open, close, low, high]
              # Note: low and high come AFTER close — counterintuitive
              data: @data[:candles] || [],
              itemStyle: {
                color:        "#ef4444",   # bearish (close < open) body
                color0:       "#22c55e",   # bullish (close > open) body
                borderColor:  "#ef4444",   # bearish wick
                borderColor0: "#22c55e"    # bullish wick
              }
            }
          ]
        )
      end
    end
  end
end
