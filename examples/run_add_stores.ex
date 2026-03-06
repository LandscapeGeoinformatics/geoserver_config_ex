# Example: bulk-create COG coverage stores for multiple time periods or indices.
#
# Run with:  mix run examples/run_add_stores.ex
#
# Export connection settings before running:
#
#   export GEOSERVER_BASE_URL="http://localhost:8080/geoserver/rest"
#   export GEOSERVER_USERNAME="admin"
#   export GEOSERVER_PASSWORD="geoserver"

conn = GeoserverConfig.Connection.from_env()

# ---------------------------------------------------------------------------
# Example 1: create stores for a spectral index across multiple years
# ---------------------------------------------------------------------------
#
# Adjust workspace, collection, index, and the COG URL template to match
# your actual data layout.

workspace = "my_workspace"
collection_short = "s2"
collection = "sentinel2"
index = "ndvi"

create_seasonal_store = fn year ->
  store_name = "#{collection_short}_#{index}_#{year}_summer"
  cog_url = "cog://https://example.com/data/#{collection}/#{index}/#{year}/#{collection_short}_#{index}_#{year}-06-01_#{year}-08-31_cog.tif"

  response = GeoserverConfig.Coveragestores.create_coveragestore(
    conn,
    workspace,
    store_name,
    cog_url,
    "#{String.upcase(index)} #{year} summer composite",
    %{
      metadata: %{
        "entry" => %{
          "@key" => "CogSettings.Key",
          "cogSettings" => %{
            "useCachingStream" => false,
            "rangeReaderSettings" => "HTTP"
          }
        }
      },
      disableOnConnFailure: false
    }
  )

  IO.inspect(response, label: store_name)
end

years = [2020, 2021, 2022, 2023]

# Uncomment to run:
# Enum.each(years, fn year ->
#   create_seasonal_store.(year)
# end)

# ---------------------------------------------------------------------------
# Example 2: create stores for a set of topographic indices
# ---------------------------------------------------------------------------

create_topo_store = fn topo_index ->
  store_name = "topo_#{topo_index}"
  cog_url = "cog://https://example.com/data/topo/#{topo_index}_10m_cog.tif"

  response = GeoserverConfig.Coveragestores.create_coveragestore(
    conn,
    workspace,
    store_name,
    cog_url,
    "Topographic index: #{topo_index}",
    %{
      metadata: %{
        "entry" => %{
          "@key" => "CogSettings.Key",
          "cogSettings" => %{
            "useCachingStream" => false,
            "rangeReaderSettings" => "HTTP"
          }
        }
      },
      disableOnConnFailure: false
    }
  )

  IO.inspect(response, label: store_name)
end

topo_indices = ["dem", "slope", "aspect", "tri", "twi"]

# Uncomment to run:
# Enum.each(topo_indices, fn index ->
#   create_topo_store.(index)
# end)
