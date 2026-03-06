# base url for geoserver "https://maps.landscape-geoinformatics.org/geoserver/rest"

# function to add stores for different indices for different years
createStore = fn year ->
  collection_short = "s2"
  collection = "sentinel2"
  index = "ndmi"
  response = GeoserverConfig.Coveragestores.create_coveragestore(
    "dcube_pub",
    "est_#{collection_short}_#{index}_#{year}_summer",
    "cog://https://s3.hpc.ut.ee/geokuup/estonia/#{collection}/#{index}/#{year}/est_#{collection_short}_#{index}_#{year}-06-01_#{year}-08-31_cog.tif",
    "Store for #{String.upcase(index)} #{year} summer",
    %{
      connectionParameters: "",
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
  IO.inspect(response)
end

years = [2017, 2018, 2019, 2020, 2021, 2022, 2023]

# run the function
# Enum.each(years, fn year ->
#   createStore.(year)
# end)

# function to add stores for topo indices
createTopoStore = fn topoIndex ->
  response = GeoserverConfig.Coveragestores.create_coveragestore(
    "dcube_pub",
    "est_topo_#{topoIndex}",
    "cog://https://s3.hpc.ut.ee/geokuup/estonia/topo/#{topoIndex}_10m_clipped_cog.tif",
    "Store for #{topoIndex}",
    %{
      connectionParameters: "",
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
  IO.inspect(response)
end

topoIndices = ["dem", "lsfaktor", "slope", "tri", "twi"]

# run the function
# Enum.each(topoIndices, fn index ->
#   createTopoStore.(index)
# end)
