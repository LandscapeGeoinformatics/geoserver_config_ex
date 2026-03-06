# Example script — run with:  mix run examples/run.exs
#
# Connection is built from environment variables at runtime.
# Export them before running:
#
#   export GEOSERVER_BASE_URL="http://localhost:8080/geoserver/rest"
#   export GEOSERVER_USERNAME="admin"
#   export GEOSERVER_PASSWORD="geoserver"

conn = GeoserverConfig.Connection.from_env()

# ---------------------------------------------------------------------------
# Workspaces
# ---------------------------------------------------------------------------

# GET — list all workspaces
# response = GeoserverConfig.Workspaces.fetch_workspaces(conn)
# IO.inspect(response)

# POST — create a workspace
# response = GeoserverConfig.Workspaces.create_workspace(conn, "my_workspace")
# IO.inspect(response)

# PUT — rename a workspace (may be rejected by GeoServer depending on version)
# response = GeoserverConfig.Workspaces.update_workspace(conn, "my_workspace", "my_workspace_renamed")
# IO.inspect(response)

# DELETE — remove a workspace
# response = GeoserverConfig.Workspaces.delete_workspace(conn, "my_workspace")
# IO.inspect(response)

# ---------------------------------------------------------------------------
# Datastores
# ---------------------------------------------------------------------------

# GET — list datastores in a workspace
# response = GeoserverConfig.Datastores.list_datastores(conn, "my_workspace")
# IO.inspect(response)

# POST — create a PostGIS datastore
# response = GeoserverConfig.Datastores.create_datastore(
#   conn,
#   "my_workspace",
#   "my_postgis_store",
#   "postgis",
#   %{
#     host: "localhost",
#     port: 5432,
#     database: "my_database",
#     user: "db_user",
#     passwd: "db_password"
#   }
# )
# IO.inspect(response)

# PUT — update a datastore
# response = GeoserverConfig.Datastores.update_datastore(conn, "my_workspace", "my_postgis_store", "postgis", %{
#   description: "Updated description",
#   host: "localhost",
#   port: 5432,
#   database: "my_database",
#   user: "db_user",
#   passwd: "db_password"
# })
# IO.inspect(response)

# DELETE — remove a datastore (recurse: true also removes dependent feature types)
# response = GeoserverConfig.Datastores.delete_datastore(conn, "my_workspace", "my_postgis_store", true)
# IO.inspect(response)

# ---------------------------------------------------------------------------
# Coverage Stores
# ---------------------------------------------------------------------------

# GET — list coverage stores in a workspace
# response = GeoserverConfig.Coveragestores.list_coveragestores(conn, "my_workspace")
# IO.inspect(response)

# POST — local GeoTIFF coverage store
# response = GeoserverConfig.Coveragestores.create_coveragestore(
#   conn,
#   "my_workspace",
#   "my_dem_store",
#   "file:///data/rasters/my_dem.tif",
#   "Digital elevation model"
# )
# IO.inspect(response)

# POST — Cloud Optimized GeoTIFF (COG) coverage store served over HTTP
# response = GeoserverConfig.Coveragestores.create_coveragestore(
#   conn,
#   "my_workspace",
#   "my_cog_store",
#   "cog://https://example.com/data/my_layer_cog.tif",
#   "COG raster served over HTTP",
#   %{
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

# PUT — update a coverage store
# response = GeoserverConfig.Coveragestores.update_coveragestore(
#   conn,
#   "my_workspace",
#   "my_dem_store",
#   %{
#     type: "GeoTIFF",
#     enabled: true,
#     url: "file:///data/rasters/my_dem_updated.tif",
#     description: "Updated description"
#   }
# )
# IO.inspect(response)

# DELETE — remove a coverage store
# response = GeoserverConfig.Coveragestores.delete_coveragestore(conn, "my_workspace", "my_cog_store")
# IO.inspect(response)

# ---------------------------------------------------------------------------
# Coverages (raster layers)
# ---------------------------------------------------------------------------

# GET — list coverages in a coverage store
# response = GeoserverConfig.Coverages.list_coverages(conn, "my_workspace", "my_dem_store")
# IO.inspect(response)

# POST — create a coverage layer
# file_path = "file:///data/rasters/my_dem.tif"
#
# response = GeoserverConfig.Coverages.create_coverage(
#   conn,
#   "my_workspace",
#   "my_dem_store",
#   "my_dem_layer",
#   %{
#     title: "My DEM Layer",
#     description: "Digital elevation model coverage",
#     abstract: "Raster coverage layer example",
#     srs: "EPSG:4326",
#     native_crs: "EPSG:4326",
#     native_bbox: %{minx: -180.0, maxx: 180.0, miny: -90.0, maxy: 90.0},
#     latlon_bbox: %{minx: -180.0, maxx: 180.0, miny: -90.0, maxy: 90.0},
#     grid: %{
#       dimension: [3600, 1800],
#       transform: [0.1, 0.0, -180.0, 0.0, -0.1, 90.0]
#     },
#     metadata: %{
#       "cacheAgeMax" => 3600,
#       "cachingEnabled" => true
#     }
#   },
#   file_path
# )
# IO.inspect(response)

# DELETE — remove a coverage layer
# response = GeoserverConfig.Coverages.delete_coverage(conn, "my_workspace", "my_dem_store", "my_dem_layer", true)
# IO.inspect(response)

# ---------------------------------------------------------------------------
# Styles
# ---------------------------------------------------------------------------

# GET — list all global styles
# response = GeoserverConfig.Styles.list_styles(conn)
# IO.inspect(response)

# GET — list workspace-specific styles
# response = GeoserverConfig.Styles.list_styles_workspace_specific(conn, "my_workspace")
# IO.inspect(response)

# POST — create a style (global; add workspace: "my_workspace" for workspace-scoped)
# sld_content = """
# <?xml version="1.0" encoding="UTF-8"?>
# <StyledLayerDescriptor version="1.0.0"
#  xsi:schemaLocation="http://www.opengis.net/sld StyledLayerDescriptor.xsd"
#  xmlns="http://www.opengis.net/sld"
#  xmlns:ogc="http://www.opengis.net/ogc"
#  xmlns:xlink="http://www.w3.org/1999/xlink"
#  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#   <NamedLayer>
#     <Name>default_raster</Name>
#     <UserStyle>
#       <Title>Default Raster</Title>
#       <Abstract>A sample style that draws a raster with 100% opacity</Abstract>
#       <FeatureTypeStyle>
#         <Rule>
#           <RasterSymbolizer>
#             <Opacity>1.0</Opacity>
#           </RasterSymbolizer>
#         </Rule>
#       </FeatureTypeStyle>
#     </UserStyle>
#   </NamedLayer>
# </StyledLayerDescriptor>
# """
#
# response = GeoserverConfig.Styles.create_style(conn, %{
#   name: "my_raster_style",
#   sld_content: sld_content,
#   filename: "my_raster_style.sld"
#   # workspace: "my_workspace"
# })
# IO.inspect(response)

# PUT — update a style
# updated_sld = """
# <?xml version="1.0" encoding="UTF-8"?>
# <StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/sld">
#   <NamedLayer>
#     <Name>my_roads</Name>
#     <UserStyle>
#       <Title>Roads Style</Title>
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
#
# response = GeoserverConfig.Styles.update_style(conn, %{
#   name: "my_raster_style",
#   sld_content: updated_sld,
#   filename: "my_raster_style.sld",
#   workspace: "my_workspace"
# })
# IO.inspect(response)

# DELETE — remove a style (recurse: true unassigns from layers first)
# response = GeoserverConfig.delete_style(conn, "my_raster_style", "my_workspace", recurse: true)
# IO.inspect(response)

# PUT — assign a style to a layer
# response = GeoserverConfig.assign_style_to_layer(conn, "my_workspace", "my_dem_layer", "my_raster_style", "my_workspace")
# IO.inspect(response)

# ---------------------------------------------------------------------------
# Layer Groups
# ---------------------------------------------------------------------------

# GET — list all layer groups
response = GeoserverConfig.list_layer_groups(conn)
IO.inspect(response)

# POST — create a layer group from XML
# xml_body = """
# <?xml version="1.0" encoding="UTF-8"?>
# <layerGroup>
#   <name>my_layer_group</name>
#   <mode>SINGLE</mode>
#   <title>My Layer Group</title>
#   <abstractTxt>A group combining multiple layers</abstractTxt>
#   <publishables>
#     <published type="layer">
#       <name>my_workspace:my_dem_layer</name>
#     </published>
#     <published type="layer">
#       <name>my_workspace:my_vector_layer</name>
#     </published>
#   </publishables>
#   <styles>
#     <style>
#       <name>my_workspace:my_raster_style</name>
#     </style>
#     <style>
#       <name>my_workspace:my_vector_style</name>
#     </style>
#   </styles>
#   <bounds>
#     <minx>-180</minx>
#     <maxx>180</maxx>
#     <miny>-90</miny>
#     <maxy>90</maxy>
#     <crs>EPSG:4326</crs>
#   </bounds>
# </layerGroup>
# """
#
# response = GeoserverConfig.create_layer_group(conn, xml_body)
# IO.inspect(response)

# POST — create a layer group from a map (JSON)
# json_body = %{
#   "layerGroup" => %{
#     "name" => "my_layer_group",
#     "mode" => "SINGLE",
#     "title" => "My Layer Group",
#     "abstractTxt" => "A group combining multiple layers",
#     "publishables" => %{
#       "published" => [
#         %{"@type" => "layer", "name" => "my_workspace:my_dem_layer"},
#         %{"@type" => "layer", "name" => "my_workspace:my_vector_layer"}
#       ]
#     },
#     "styles" => %{
#       "style" => [
#         %{"name" => "my_workspace:my_raster_style"},
#         %{"name" => "my_workspace:my_vector_style"}
#       ]
#     },
#     "bounds" => %{
#       "minx" => -180, "maxx" => 180, "miny" => -90, "maxy" => 90,
#       "crs" => "EPSG:4326"
#     }
#   }
# }
#
# response = GeoserverConfig.create_layer_group(conn, json_body)
# IO.inspect(response)

# PUT — update a layer group (XML or map)
# xml_update_body = """
# <?xml version="1.0" encoding="UTF-8"?>
# <layerGroup>
#   <name>my_layer_group</name>
#   <title>My Updated Layer Group</title>
#   <publishables>
#     <published type="layer"><name>my_workspace:my_dem_layer</name></published>
#     <published type="layer"><name>my_workspace:my_vector_layer</name></published>
#     <published type="layer"><name>my_workspace:my_extra_layer</name></published>
#   </publishables>
#   <styles>
#     <style><name>my_workspace:my_raster_style</name></style>
#     <style><name>my_workspace:my_vector_style</name></style>
#     <style><name>my_workspace:my_extra_style</name></style>
#   </styles>
# </layerGroup>
# """
#
# response = GeoserverConfig.update_layer_group(conn, "my_layer_group", xml_update_body)
# IO.inspect(response)

# DELETE — remove a layer group
# response = GeoserverConfig.delete_layer_group(conn, "my_layer_group")
# IO.inspect(response)

# Adding a layer to an existing layer group
# response = GeoserverConfig.add_layer_to_group(conn, "my_layer_group", "my_workspace:my_extra_layer", "my_workspace:my_extra_style")
# IO.inspect(response)

# Removing a layer from a layer group
# response = GeoserverConfig.remove_layer_from_group(conn, "my_layer_group", "my_workspace:my_extra_layer")
# IO.inspect(response)
