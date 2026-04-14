# app/views/components/charts/industry_theme_river.rb
#
# ThemeRiver showing business sales composition by industry over time.
#
# Service: Stats::BusinessCompositionTimeline — build this service:
#   Returns an array of [date_string, value, industry_name] triples.
#   [
#     ["2005-01-01", 142.3, "Mining"],
#     ["2005-01-01",  98.7, "Manufacturing"],
#     ["2005-04-01", 148.1, "Mining"],
#     ...
#   ]
#
# Wire up:
#   def industry_theme_river
#     @data = Stats::BusinessCompositionTimeline.call
#   end
#
# Stats::BusinessCompositionTimeline:
#   BusinessIndicatorReading
#     .order(:year, :quarter)
#     .pluck(:year, :quarter, :sales_billions, :industry)
#     .map { |y, q, sales, ind|
#       [Date.new(y, (q * 3) - 2, 1).to_s, sales.to_f.round(1), ind]
#     }

module Components
  module Charts
    class IndustryThemeRiver < Components::Chart
      prop :data, _Any, default: -> { [] }

      private

      def chart_options
        ::Chart::Options.new(
          color:   "tableau",
          tooltip: {
            trigger:   "axis",
            formatter: "thousands"
          },
          legend:      {
            type:   "scroll",
            bottom: 5,
            data:   industries
          },
          # ThemeRiver uses singleAxis — not xAxis/yAxis
          singleAxis: {
            type:   "time",
            bottom: 60
          },
          series: [
            {
              type:     "themeRiver",
              emphasis: { focus: "series" },
              data:     @data   # [[date, value, industry], ...]
            }
          ]
        )
      end

      def industries
        @data.map(&:last).uniq.sort
      end
    end
  end
end
