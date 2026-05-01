#!/usr/bin/env ruby
# frozen_string_literal: true
#
# bin/normalise-sa3-data
#
# Merges mapshaper-simplified geometry with the original ABS feature
# attributes, normalises property names to lowercase, and generates
# synthetic populations.
#
# Why this script exists:
#   The mapshaper online tool simplifies geometries effectively but
#   strips properties on export (it doesn't recognise the ABS
#   attribute names by default and clears them). We need to glue
#   the attributes back from the original unsimplified file.
#
# Inputs:
#   db/data/.sa3-raw.geojson         - the original ABS response
#   db/data/sa3-simplified.geojson   - the mapshaper output
#                                       (drop the file you exported
#                                        from mapshaper online here,
#                                        with this filename)
#
# Output:
#   db/data/sa3.geojson              - the file the tutorial imports
#
# This is a chassis maintenance script. Run once during chassis
# preparation; the result is vendored.

require "json"
require "fileutils"

ROOT = File.expand_path("..", __dir__)

RAW_PATH        = "sa3-raw.geojson"
SIMPLIFIED_PATH = "sa3-simplified.geojson"
OUTPUT_PATH     = "sa3.geojson"

abort "Missing #{RAW_PATH} - run bin/fetch-sa3-data first"        unless File.exist?(RAW_PATH)
abort "Missing #{SIMPLIFIED_PATH} - export from mapshaper to this name" unless File.exist?(SIMPLIFIED_PATH)

puts "Reading source files..."
raw        = JSON.parse(File.read(RAW_PATH))
simplified = JSON.parse(File.read(SIMPLIFIED_PATH))

raw_features        = raw["features"]
simplified_features = simplified["features"]

unless raw_features.size == simplified_features.size
  abort "Feature count mismatch: raw=#{raw_features.size} simplified=#{simplified_features.size}"
end

puts "Merging #{raw_features.size} features..."

# Generate a deterministic synthetic population from the SA3 code,
# weighted by the GCCSA category. See db/data/README.md for the
# rationale.
def synthetic_population(sa3_code, gccsa_name)
  weight = case gccsa_name.to_s
           when /Greater/i, /Capital/i then 1.5
           when /Rest/i                then 0.7
           else                              1.0
           end
  base = (sa3_code.to_s.bytes.sum % 100) / 100.0
  (30_000 + base * 100_000 * weight).floor
end

merged = raw_features.zip(simplified_features).filter_map do |raw_feature, simp_feature|
  geometry = simp_feature["geometry"]

  # ABS includes administrative pseudo-features with no geometry —
  # "Migratory - Offshore - Shipping", "No usual address", "Outside
  # Australia". They're real census categories but they have no
  # mappable boundary. Skip them.
  next nil if geometry.nil? ||
              geometry["coordinates"].nil? ||
              geometry["coordinates"].empty?

  raw_props = raw_feature["properties"]
  sa3_code   = raw_props["sa3_code_2021"]
  sa3_name   = raw_props["sa3_name_2021"]
  sa4_name   = raw_props["sa4_name_2021"]
  gccsa_name = raw_props["gccsa_name_2021"]
  state      = raw_props["state_name_2021"]

  {
    "type" => "Feature",
    "geometry" => geometry,
    "properties" => {
      "sa3_code"   => sa3_code,
      "sa3_name"   => sa3_name,
      "sa4_name"   => sa4_name,
      "gccsa_name" => gccsa_name,
      "state"      => state,
      "population" => synthetic_population(sa3_code, gccsa_name)
    }
  }
end

output = {
  "type"     => "FeatureCollection",
  "features" => merged
}

File.write(OUTPUT_PATH, JSON.generate(output))

size_kb = File.size(OUTPUT_PATH) / 1024
skipped_count = raw_features.size - merged.size
puts "Done."
puts "  Output: #{OUTPUT_PATH}"
puts "  Features kept: #{merged.size}"
puts "  Features skipped (no geometry): #{skipped_count}"
puts "  Size: #{size_kb} KB"
puts ""
puts "Sample feature:"
sample = merged.first
puts "  Properties: #{sample['properties'].inspect}"
puts "  Geometry type: #{sample['geometry']['type']}"
puts "  Vertex sample: #{sample['geometry']['coordinates'].first.first.first(2).inspect}..."
