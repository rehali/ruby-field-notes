# app/views/components/charts/gdp_treemap.rb
#
# Treemap showing GDP composition by industry for the latest quarter.
#
# Service: Stats::GdpLatestQuarter — returns:
#   [{ industry: "Mining", value: 142.3 }, ...]
#
# Wire up:
#   def gdp_treemap
#     @data = Stats::GdpLatestQuarter.call
#   end

module Components
  module Charts
    class GdpTreemap < Components::Chart
      prop :data, _Any, default: -> { [] }

      private

      def chart_options
        ::Chart::Options.new(
          color:   "earth",
          tooltip: {
            trigger:   "item",
            formatter: "item:billions"
          },
          series: [
            {
              type:      "treemap",
              data:      tree_data,
              visibleMin: 300,
              label: {
                show:      true,
                formatter: "{b}\n${c}B"
              },
              upperLabel: {
                show:   true,
                height: 30
              },
              itemStyle: {
                borderColor: "#fff",
                borderWidth: 2,
                gapWidth:    2
              },
              levels: [
                {
                  itemStyle: {
                    borderWidth: 3,
                    gapWidth:    3,
                    borderColor: "#555"
                  }
                },
                {
                  itemStyle: {
                    borderWidth: 2,
                    gapWidth:    2
                  }
                }
              ]
            }
          ]
        )
      end

      def tree_data
        @data.map do |r|
          { name: r[:industry], value: r[:value] }
        end
      end
    end
  end
end
