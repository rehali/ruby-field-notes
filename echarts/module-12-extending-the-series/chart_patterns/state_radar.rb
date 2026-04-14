# app/views/components/charts/state_radar.rb
#
# Radar chart comparing states across four labour force metrics
# for the latest available year.
#
# Service: Stats::LabourForceSnapshot — returns:
#   { "New South Wales" => { employed: 4100.0, unemployed: 158.0,
#                            participation: 63.2, rate: 3.8 }, ... }
#
# Wire up:
#   def state_radar
#     year  = LabourForceReading.maximum(:year)
#     @data = Stats::LabourForceSnapshot.call(year: year)
#   end

module Components
  module Charts
    class StateRadar < Components::Chart
      prop :data, _Any, default: -> { {} }

      private

      def chart_options
        ::Chart::Options.new(
          color:   "tableau",
          tooltip: { trigger: "item" },
          legend:  { type: "scroll", bottom: 5 },
          radar:   {
            indicator: [
              { name: "Employed ('000)", max: 5000 },
              { name: "Participation (%)", max: 80 },
              { name: "Unemployment (%)", max: 12 },
              { name: "Unemployed ('000)", max: 400 }
            ],
            shape:  "polygon",
            radius: "60%",
            center: ["50%", "48%"]
          },
          series: [
            {
              type: "radar",
              data: radar_data
            }
          ]
        )
      end

      def radar_data
        @data.map do |state, metrics|
          {
            name:  state,
            value: [
              metrics[:employed],
              metrics[:participation],
              metrics[:rate],
              metrics[:unemployed]
            ]
          }
        end
      end
    end
  end
end
