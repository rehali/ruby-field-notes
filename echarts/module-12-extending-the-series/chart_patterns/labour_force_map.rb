# app/views/components/charts/labour_force_map.rb
#
# Choropleth map of Australia coloured by unemployment rate by state.
#
# GeoJSON Setup:
#   The Australian states file is provided with this download.
#
#   Pin in config/importmap.rb:
#     pin "australia_map", to: "charts/australia_map.js"
#
#   Import once in app/javascript/application.js:
#     import "australia_map"
#
# Wire up:
#   def labour_force_map
#     @year = (params[:year] || 2014).to_i
#     @data = Stats::LabourForceSnapshot.call(year: @year)
#   end

module Components
  module Charts
    class LabourForceMap < Components::Chart
      prop :data, _Any,    default: -> { {} }
      prop :year, Integer, default: -> { 2014 }

      private

      def chart_options
        ::Chart::Options.new(
          tooltip: {
            trigger:   "item",
            formatter: "item:rate"
          },
          # Piecewise (discrete) visualMap — better than continuous for
          # data with a narrow range. Bands tuned to 2014 unemployment data.
          visualMap: {
            type:   "piecewise",
            pieces: [
              { min: 0, max: 4, label: "< 4%",  color: "#22c55e" },
              { min: 4, max: 5, label: "4–5%",  color: "#86efac" },
              { min: 5, max: 6, label: "5–6%",  color: "#fbbf24" },
              { min: 6, max: 7, label: "6–7%",  color: "#f97316" },
              { min: 7,         label: "> 7%",  color: "#ef4444" }
            ],
            orient: "horizontal",
            left:   "center",
            bottom: 40
          },
          geo: {
            map:       "australia",
            roam:      false,
            center:    [134.0, -26.0],
            zoom:      1.1,
            label: {
              show:     true,
              fontSize: 10,
              color:    "#333"
            },
            itemStyle: {
              areaColor:   "#f5f5f5",
              borderColor: "#999",
              borderWidth: 1
            },
            emphasis: {
              label:     { show: true },
              itemStyle: { areaColor: "#cfe2f3" }
            }
          },
          series: [
            {
              type:     "map",
              map:      "australia",
              geoIndex: 0,
              name:     "Unemployment Rate #{@year}",
              data:     map_data
            }
          ]
        )
      end

      def map_data
        @data.map do |state, metrics|
          { name: state, value: metrics[:rate] }
        end
      end
    end
  end
end