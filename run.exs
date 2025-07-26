# WorkSpaces GET Method
# response = GeoserverConfig.Workspaces.fetch_workspaces()
# IO.inspect(response)

# Workspace POST Method
# response = GeoserverConfig.Workspaces.create_workspace("demo_test")
# IO.inspect(response)

# Workspace PUT Method (Its unautorized to change the name of Workspace, but If you use the same name then it gets updated(no use at all)).
# response = GeoserverConfig.Workspaces.update_workspace("new_workspace_name", "new_name")
# IO.inspect(response)

# Workspace DELETE Method
# GeoserverConfig.Workspaces.delete_workspace("new_workspace_name")

#DataStores GET Method
# response = GeoserverConfig.Datastores.list_datastores("demo_test")
# IO.inspect(response)

# Datastore POST Method
# response = GeoserverConfig.Datastores.create_datastore(
#   "demo_test",  # Workspace name
#   "demostore_postgis_test",  # Datastore name
#   "postgis",  # The datastore type
#   %{
#     host: "localhost",
#     port: 5432,
#     database: "opengeo",
#     user: "opengeo",
#     passwd: "opengeo"
#   }
# )
# IO.inspect(response)

# DataStore PUT Method
# response = GeoserverConfig.Datastores.update_datastore("demo_test", "demostore_postgis_test", "postgis", %{
#   description: "new",
#   host: "localhost",
#   port: 5432,
#   database: "opengeo",
#   user: "opengeo",
#   passwd: "opengeo"
# })
# IO.inspect(response)

# Datastore DELETE Method
# response = GeoserverConfig.Datastores.delete_datastore("demo_test", "demostore_postgis_test", true)
# IO.inspect(response)

# CoverageStore GET Method
# response = GeoserverConfig.Coveragestores.list_coveragestores("demo_test1")
# IO.inspect(response)

# CoverageStore POST Method
# response = GeoserverConfig.Coveragestores.create_coveragestore(
#   "demo_test",        # Workspace name
#   "dem_3x3_test",     # Coverage store name
#   "file:///home/geoadmin/run/ut_sdi_2021/SDI/dems/dem_3x3.tif",  # Local GeoTIFF file path
#   "A description of the coverage store" # Coverage store description
# )
# IO.inspect(response)

# POST METHOD "COG GeoTIFF" Coverage Store
# response = GeoserverConfig.Coveragestores.create_coveragestore(
#   "demo_test",
#   "demo_cog_test",
#   "cog://https://storage.googleapis.com/geo-assets/dcube_pub/estonia/sentinel2/ndvi/2024/est_s2_ndvi_2024-06-01_2024-08-31_cog.tif",
#   "Test for GeoTIFF COG",
#   %{
#     connectionParameters: "",
#     metadata: %{
#       "entry" => %{
#         "@key" => "CogSettings.Key",
#         "cogSettings" => %{
#           "useCachingStream" => false,
#           "rangeReaderSettings" => "HTTP"
#         }
#       }
#     },
#     disableOnConnFailure: false
#   }
# )
# IO.inspect(response)

# PUT Method CoverageStore
# response = GeoserverConfig.Coveragestores.update_coveragestore(
#   "demo_test",           # workspace
#   "dem_3x3_test1",       # store name
#   %{
#     type: "GeoTIFF",
#     enabled: true,
#     url: "file:///home/geoadmin/run/ut_sdi_2021/SDI/dems/dem_3x3.tif",
#     description: "Updated description"
#   }
# )
# IO.inspect(response)

# CoverageStore DELETE Method
# response = GeoserverConfig.Coveragestores.delete_coveragestore("demo_test", "demo_cog_test")
# IO.inspect(response)

# response = GeoserverConfig.Coveragestores.create_coveragestores_from_csv("coverage.csv")
# IO.inspect(response)

# GET Method: List of Coverages
# response = GeoserverConfig.list_coverages("demo_test", "dem_3x3_test")
# IO.inspect(response)

# POST Method: Creation of Coverage Layers
# file_path = "file:///home/geoadmin/run/ut_sdi_2021/SDI/dems/dem_3x3.tif"

# response = GeoserverConfig.Coverages.create_coverage(
#   "demo_test",
#   "dem_3x3_test",
#   "dem_test_coverage1",
#   %{
#     title: "dem_test_coverage1",
#     description: "Testing Layers for Geotiff",
#     abstract: "Testing the Coverage Store",
#     srs: "EPSG:3301",
#     native_crs: "EPSG:3301",
#     native_bbox: %{minx: 369000.0, maxx: 740000.0, miny: 6377000.0, maxy: 6635000.0},
#     latlon_bbox: %{minx: 21.664072036889028, maxx: 28.275493984062805, miny: 57.47121886444548, maxy: 59.83122737438482},
#     grid: %{
#       dimension: [634, 477],
#       transform: [10.0, 0.0, 369000.0, 0.0, -10.0, 6635000.0]
#     },
#     metadata: %{
#       "cacheAgeMax" => 3600,
#       "cachingEnabled" => true
#     }
#   },
#   file_path
# )

# IO.inspect(response)

# DELETE Method: Delete specific coverage
# response = GeoserverConfig.delete_coverage("demo_testas", "dem_3x3_test", "dem_test_coverage1", "true")
# IO.inspect(response)

# GET Method: Styles
# response = GeoserverConfig.list_styles()
# IO.inspect(response)

# # GET Method: Styles (Workspace Specific)
# response = GeoserverConfig.list_styles_workspace_specific("demo_test")
# IO.inspect(response)

# POST Method: Styles
# sld_content = """
# <?xml version="1.0" encoding="UTF-8"?>
# <StyledLayerDescriptor version="1.0.0"
#  xsi:schemaLocation="http://www.opengis.net/sld StyledLayerDescriptor.xsd"
#  xmlns="http://www.opengis.net/sld"
#  xmlns:ogc="http://www.opengis.net/ogc"
#  xmlns:xlink="http://www.w3.org/1999/xlink"
#  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#   <!-- a Named Layer is the basic building block of an SLD document -->
#   <NamedLayer>
#     <Name>default_raster</Name>
#     <UserStyle>
#     <!-- Styles can have names, titles and abstracts -->
#       <Title>Default Raster</Title>
#       <Abstract>A sample style that draws a raster, good for displaying imagery</Abstract>
#       <!-- FeatureTypeStyles describe how to render different features -->
#       <!-- A FeatureTypeStyle for rendering rasters -->
#       <FeatureTypeStyle>
#         <Rule>
#           <Name>rule1</Name>
#           <Title>Opaque Raster</Title>
#           <Abstract>A raster with 100% opacity</Abstract>
#           <RasterSymbolizer>
#             <Opacity>1.0</Opacity>
#           </RasterSymbolizer>
#         </Rule>
#       </FeatureTypeStyle>
#     </UserStyle>
#   </NamedLayer>
# </StyledLayerDescriptor>
# """

# response = GeoserverConfig.Styles.create_style(%{
#   name: "dem_test_style",
#   sld_content: sld_content,
#   filename: "dem.sld",
#   #workspace: "demo_test" #This line defines if you want the style Workspace specific or without Workspace
#   })
#   IO.inspect(response)


# PUT Method: Styles
# updated_sld = """
# <?xml version="1.0" encoding="UTF-8"?>
# <StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld">
#   <NamedLayer>
#     <Name>Ghichkam</Name>
#     <UserStyle>
#       <Title>Updated Roads Style</Title>
#       <FeatureTypeStyle>
#         <Rule>
#           <LineSymbolizer>
#             <Stroke>
#               <CssParameter name="stroke">#0000FF</CssParameter>
#               <CssParameter name="stroke-width">3</CssParameter>
#             </Stroke>
#           </LineSymbolizer>
#         </Rule>
#       </FeatureTypeStyle>
#     </UserStyle>
#   </NamedLayer>
# </StyledLayerDescriptor>
# """

# response = GeoserverConfig.Styles.update_style(%{
#   name: "dem_test_style1",
#   sld_content: updated_sld,
#   filename: "updated_dem.sld",
#   workspace: "demo_test"
# })
# IO.inspect(response)


# DELETE Method: Styles (We need to add workspace name of style if workspace specific and recurse:true to TRUE if style is assigned to layer)
# response = GeoserverConfig.delete_style("dem_test_style1", "demo_test", recurse: true)
# IO.inspect(response)


# PUT Method Style to Layer
# response = GeoserverConfig.assign_style_to_layer("demo_test", "dem_test_coverage1", "dem_test_style", "demo_test")
# IO.inspect(response)


# LayerGroups GET Method
# response = GeoserverConfig.list_layer_groups().body
# IO.inspect(response)


# LayerGroups POST Method
# xml_body = """
# <?xml version="1.0" encoding="UTF-8"?>
# <layerGroup>
#   <name>demo_test_layergroup123</name>
#   <mode>SINGLE</mode>
#   <title>Demo Layer Group</title>
#   <abstractTxt>A description here</abstractTxt>
#   <publishables>
#     <published type="layer">
#       <name>sf:sfdem</name>
#     </published>
#     <published type="layer">
#       <name>sf:streams</name>
#     </published>
#   </publishables>
#   <styles>
#     <style>
#       <name>sf:dem</name>
#     </style>
#     <style>
#       <name>sf:simple_streams</name>
#     </style>
#   </styles>
#   <metadataLinks>
#     <metadataLink>
#       <type>text/xml</type>
#       <metadataType>FGDC</metadataType>
#       <content>http://example.com/metadata.xml</content>
#     </metadataLink>
#   </metadataLinks>
#   <bounds>
#     <minx>-180</minx>
#     <maxx>180</maxx>
#     <miny>-90</miny>
#     <maxy>90</maxy>
#     <crs>EPSG:4326</crs>
#   </bounds>
#   <keywords>
#     <string>example</string>
#   </keywords>
# </layerGroup>
# """

# response = GeoserverConfig.create_layer_group(xml_body)
# IO.inspect(response)


# LayerGroups PUT Method
# xml_update_body = """
# <?xml version="1.0" encoding="UTF-8"?>
# <layerGroup>
#   <name>demo_test_layergroup123</name>
#   <mode>SINGLE</mode>
#   <title>Updated Title</title>
#   <abstractTxt>Updated description</abstractTxt>
#   <publishables>
#     <published type="layer">
#       <name>sf:sfdem</name>
#       </published>
#     <published type="layer">
#       <name>sf:roads</name>
#     </published>
#     <published type="layer">
#       <name>sf:restricted</name>
#     </published>
#   </publishables>
#   <styles>
#     <style>
#       <name>sf:dem</name>
#       </style>
#     <style>
#       <name>sf:simple_roads</name>
#       </style>
#     <style>
#       <name>sf:restricted</name>
#       </style>
#   </styles>
#   <metadataLinks>
#     <metadataLink>
#       <type>text/xml</type>
#       <metadataType>FGDC</metadataType>
#       <content>http://example.com/metadata.xml</content>
#     </metadataLink>
#   </metadataLinks>
#   <bounds>
#     <minx>-180</minx>
#     <maxx>180</maxx>
#     <miny>-90</miny>
#     <maxy>90</maxy>
#     <crs>EPSG:4326</crs>
#   </bounds>
#   <keywords>
#     <string>updated</string> </keywords>
# </layerGroup>
# """

# response = GeoserverConfig.update_layer_group("demo_test_layergroup123", xml_update_body)
# IO.inspect(response)

# LayerGroups DELETE Method
# response = GeoserverConfig.delete_layer_group("demo_test_layergroup123")
# IO.inspect(response)
