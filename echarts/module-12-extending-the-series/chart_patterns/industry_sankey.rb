# app/views/components/charts/industry_sankey.rb
#
# Sankey diagram showing GDP flow from industry groups to total GDP.
#
# Service: Stats::GdpSankey — build this service:
# Groups industries into sectors, shows flow from industry → sector → GDP.
#
# Returns:
# {
#   nodes: [
#     { name: "Mining" },
#     { name: "Primary Industries" },
#     { name: "Total GDP" },
#     ...
#   ],
#   links: [
#     { source: "Mining",       target: "Primary Industries", value: 142.3 },
#     { source: "Agriculture",  target: "Primary Industries", value: 38.1  },
#     { source: "Primary Industries", target: "Total GDP",   value: 180.4 },
#     ...
#   ]
# }
#
# Wire up:
#   def industry_sankey
#     @data = Stats::GdpSankey.call
#   end

module Components
  module Charts
    class IndustrySankey < Components::Chart
      prop :data, _Any, default: -> { {} }

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
              type:       "sankey",
              layout:     "none",
              emphasis:   { focus: "adjacency" },
              data:       @data[:nodes] || [],
              links:      @data[:links] || [],
              nodeAlign:  "left",
              lineStyle:  {
                color:     "source",
                curveness: 0.5,
                opacity:   0.4
              },
              label: {
                position: "right",
                fontSize: 11
              }
            }
          ]
        )
      end
    end
  end
end
