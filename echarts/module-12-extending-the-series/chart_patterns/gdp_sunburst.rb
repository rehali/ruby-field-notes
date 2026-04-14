# app/views/components/charts/gdp_sunburst.rb
#
# Sunburst chart showing GDP by industry grouped into sectors.
#
# Service: Stats::GdpBySector — build this service to group industries
# into sectors:
#
# SECTORS = {
#   "Services" => [
#     "Financial and Insurance Services",
#     "Professional, Scientific and Technical Services",
#     "Health Care and Social Assistance",
#     "Education and Training",
#     "Public Administration and Safety",
#     "Retail Trade",
#     "Accommodation and Food Services",
#     "Administrative and Support Services",
#     "Arts and Recreation Services",
#     "Other Services"
#   ],
#   "Goods-Producing" => [
#     "Manufacturing",
#     "Construction",
#     "Electricity, Gas, Water and Waste Services"
#   ],
#   "Primary" => [
#     "Mining",
#     "Agriculture, Forestry and Fishing"
#   ],
#   "Other" => [
#     "Information Media and Telecommunications",
#     "Transport, Postal and Warehousing",
#     "Rental, Hiring and Real Estate Services",
#     "Wholesale Trade"
#   ]
# }
#
# Returns nested structure:
# [
#   {
#     name: "Services",
#     children: [
#       { name: "Financial and Insurance Services", value: 98.7 },
#       ...
#     ]
#   },
#   ...
# ]
#
# Wire up:
#   def gdp_sunburst
#     @data = Stats::GdpBySector.call
#   end

module Components
  module Charts
    class GdpSunburst < Components::Chart
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
              type:     "sunburst",
              data:     @data,
              radius:   ["15%", "80%"],
              emphasis: { focus: "ancestor" },
              label: {
                rotate: "radial",
                fontSize: 10
              },
              levels: [
                {},
                {
                  r0:    "15%",
                  r:     "40%",
                  label: { rotate: 0, fontSize: 12, fontWeight: "bold" }
                },
                {
                  r0:    "40%",
                  r:     "72%",
                  label: { rotate: "radial", fontSize: 9 }
                },
                {
                  r0:    "72%",
                  r:     "80%",
                  label: { position: "outside", fontSize: 9 }
                }
              ]
            }
          ]
        )
      end
    end
  end
end
