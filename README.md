# GeoServer Configuration Elixir Client

An Elixir library for interacting with GeoServer's REST API to manage workspaces,
datastores, coverage stores, coverages, styles, and layer groups.

## Prerequisites

- Elixir 1.17+
- A running GeoServer instance with the REST API enabled
- Valid GeoServer credentials

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:geoserver_config, "~> 0.2.4"}
  ]
end
```

## Connection

Every API function takes a `GeoserverConfig.Connection` as its first argument.
Build one at application startup and pass it wherever needed.

**From environment variables** (read at runtime, never at compile time):

```bash
export GEOSERVER_BASE_URL="http://localhost:8080/geoserver/rest"
export GEOSERVER_USERNAME="admin"
export GEOSERVER_PASSWORD="geoserver"
```

```elixir
conn = GeoserverConfig.Connection.from_env()
```

**From explicit values:**

```elixir
conn = GeoserverConfig.Connection.new(
  "http://localhost:8080/geoserver/rest",
  "admin",
  "geoserver"
)
```

**From your application's config** (`config/runtime.exs`):

```elixir
# config/runtime.exs
config :my_app, :geoserver,
  base_url: System.get_env("GEOSERVER_BASE_URL"),
  username: System.get_env("GEOSERVER_USERNAME"),
  password: System.get_env("GEOSERVER_PASSWORD")
```

```elixir
conn = GeoserverConfig.Connection.from_application_env(:my_app)
# custom key: GeoserverConfig.Connection.from_application_env(:my_app, :geo_api)
```

**Custom env prefix** (useful for multiple GeoServer instances):

```elixir
# reads STAGING_GEOSERVER_BASE_URL, STAGING_GEOSERVER_USERNAME, ...
conn = GeoserverConfig.Connection.from_env(prefix: "STAGING_GEOSERVER")
```

## Workspace Operations

```elixir
{:ok, workspaces} = GeoserverConfig.Workspaces.fetch_workspaces(conn)

{:ok, "new_ws"} = GeoserverConfig.Workspaces.create_workspace(conn, "new_ws")

{:ok, "new_name"} = GeoserverConfig.Workspaces.update_workspace(conn, "old_name", "new_name")

{:ok, "old_ws"} = GeoserverConfig.Workspaces.delete_workspace(conn, "old_ws")
```

> Note: GeoServer may reject workspace renames depending on its version and configuration.

## Datastore Operations

```elixir
{:ok, stores} = GeoserverConfig.Datastores.list_datastores(conn, "workspace_name")
```

**Shapefile (with enhanced options):**

```elixir
# Basic shapefile directory
{:ok, "my_store"} = GeoserverConfig.Datastores.create_datastore(
  conn,
  "workspace_name",
  "my_store",
  "shapefile",
  %{url: "file:///path/to/shapefile_directory"}
)

# Shapefile with charset support
{:ok, "my_store"} = GeoserverConfig.Datastores.create_datastore(
  conn,
  "workspace_name",
  "my_store",
  "shapefile",
  %{url: "file:///path/to/shapes", charset: "ISO-8859-1"}
)
```

**PostGIS (with comprehensive connection parameters):**

```elixir
# Basic PostGIS connection
{:ok, "my_store"} = GeoserverConfig.Datastores.create_datastore(
  conn,
  "workspace_name",
  "my_store",
  "postgis",
  %{
    host: "localhost",
    port: 5432,
    database: "db_name",
    user: "db_user",
    passwd: "db_password"
  }
)

# Enhanced PostGIS with connection pooling and performance settings
{:ok, "my_store"} = GeoserverConfig.Datastores.create_datastore(
  conn,
  "workspace_name",
  "my_store",
  "postgis",
  %{
    host: "localhost",
    port: 5432,
    database: "db_name",
    user: "db_user",
    passwd: "db_password",
    schema: "custom_schema",
    "max connections": "20",
    "min connections": "5",
    "Connection timeout": "30",
    "Loose bbox": "true",
    "Estimated extends": "true",
    "Expose primary keys": "true"
  }
)
```

**GeoPackage (with table support):**

```elixir
# Basic GeoPackage
{:ok, "my_store"} = GeoserverConfig.Datastores.create_datastore(
  conn,
  "workspace_name",
  "my_store",
  "geopkg",
  %{database: "file:///path/to/file.gpkg"}
)

# GeoPackage with specific table
{:ok, "my_store"} = GeoserverConfig.Datastores.create_datastore(
  conn,
  "workspace_name",
  "my_store",
  "geopkg",
  %{database: "file:///path/to/file.gpkg", table: "my_layer"}
)
```

**Update:**

```elixir
{:ok, "my_store"} = GeoserverConfig.Datastores.update_datastore(
  conn,
  "workspace_name",
  "my_store",
  "shapefile",
  %{description: "New description", url: "file:///new/path"}
)
```

**Delete** (`recurse: true` also removes dependent feature types):

```elixir
{:ok, "my_store"} = GeoserverConfig.Datastores.delete_datastore(conn, "workspace_name", "my_store", true)
```

## Feature Types (Vector Layers)

Feature types represent vector layers published from datastores. These operations allow you to manage vector data layers for WMS/WFS services.

```elixir
# List all configured feature types in a datastore
{:ok, feature_types} = GeoserverConfig.list_featuretypes(conn, "workspace_name", "datastore_name")

# List available (unpublished) feature types
{:ok, available_types} = GeoserverConfig.list_featuretypes(conn, "workspace_name", "datastore_name", :available)

# List all feature types (configured + available)
{:ok, all_types} = GeoserverConfig.list_featuretypes(conn, "workspace_name", "datastore_name", :all)
```

**Create vector layers with comprehensive metadata:**

```elixir
{:ok, "my_layer"} = GeoserverConfig.create_featuretype(
  conn,
  "workspace_name",
  "datastore_name",
  "my_layer",
  %{
    title: "My Vector Layer",
    description: "Detailed description of the layer",
    abstract: "Abstract text for metadata",
    srs: "EPSG:4326",
    native_crs: "EPSG:3857",
    native_bbox: %{minx: -180.0, maxx: 180.0, miny: -90.0, maxy: 90.0},
    latlon_bbox: %{minx: -180.0, maxx: 180.0, miny: -90.0, maxy: 90.0},
    enabled: true,
    keywords: ["vector", "roads", "transportation"],
    metadata: %{"cacheAgeMax" => 3600, "cachingEnabled" => true}
  }
)
```

**Update existing vector layers:**

```elixir
{:ok, "my_layer"} = GeoserverConfig.update_featuretype(
  conn,
  "workspace_name",
  "datastore_name",
  "my_layer",
  %{
    title: "Updated Title",
    description: "Updated description",
    srs: "EPSG:3857"
  }
)

# Update with bounding box recalculation
{:ok, "my_layer"} = GeoserverConfig.update_featuretype(
  conn,
  "workspace_name",
  "datastore_name",
  "my_layer",
  %{title: "Updated Title"},
  "nativebbox,latlonbbox"  # Recalculate both bounding boxes
)
```

**Delete vector layers:**

```elixir
# Delete layer (recurse: true removes dependent resources)
{:ok, "my_layer"} = GeoserverConfig.delete_featuretype(
  conn,
  "workspace_name",
  "datastore_name",
  "my_layer",
  true  # recurse
)
```

## Coverage Store Operations

```elixir
{:ok, stores} = GeoserverConfig.Coveragestores.list_coveragestores(conn, "workspace_name")
```

**Local GeoTIFF:**

```elixir
{:ok, "dem_store"} = GeoserverConfig.Coveragestores.create_coveragestore(
  conn,
  "workspace_name",
  "dem_store",
  "file:///path/to/geotiff.tif",
  "Optional description"
)
```

**Cloud Optimized GeoTIFF (COG) via S3 or HTTP:**

```elixir
{:ok, "dem_store"} = GeoserverConfig.Coveragestores.create_coveragestore(
  conn,
  "workspace_name",
  "dem_store",
  "cog://https://path.to/your/file_cog.tif",
  "COG from HTTP",
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
```

**Update:**

```elixir
{:ok, "dem_store"} = GeoserverConfig.Coveragestores.update_coveragestore(
  conn,
  "workspace_name",
  "dem_store",
  %{
    type: "GeoTIFF",
    enabled: true,
    url: "file:///new/path/to/file.tif",
    description: "Updated description"
  }
)
```

**Delete** (uses `purge=true` to remove related resources):

```elixir
{:ok, "dem_store"} = GeoserverConfig.Coveragestores.delete_coveragestore(conn, "workspace_name", "dem_store")
```

## Coverage Layer Operations

```elixir
{:ok, coverages} = GeoserverConfig.Coverages.list_coverages(conn, "workspace_name", "dem_store")
```

**Create:**

```elixir
{:ok, "dem_layer"} = GeoserverConfig.Coverages.create_coverage(
  conn,
  "workspace_name",
  "dem_store",
  "dem_layer",
  %{
    title: "DEM Layer",
    description: "Digital Elevation Model",
    abstract: "Raster coverage layer",
    srs: "EPSG:3301",
    native_crs: "EPSG:3301",
    native_bbox: %{minx: 369000.0, maxx: 740000.0, miny: 6377000.0, maxy: 6635000.0},
    latlon_bbox: %{minx: 21.664, maxx: 28.275, miny: 57.471, maxy: 59.831},
    grid: %{
      dimension: [3710, 2580],
      transform: [10.0, 0.0, 369000.0, 0.0, -10.0, 6635000.0]
    },
    metadata: %{
      "cacheAgeMax" => 3600,
      "cachingEnabled" => true
    }
  },
  "file:///path/to/geotiff.tif"
)
```

**Delete** (`recurse: true` also removes dependent resources):

```elixir
{:ok, "dem_layer"} = GeoserverConfig.Coverages.delete_coverage(conn, "workspace_name", "dem_store", "dem_layer", true)
```

## Style Operations

```elixir
{:ok, styles} = GeoserverConfig.Styles.list_styles(conn)

{:ok, styles} = GeoserverConfig.Styles.list_styles_workspace_specific(conn, "workspace_name")
```

**Get style content** (pass `nil` as workspace for global styles):

```elixir
{:ok, sld_xml} = GeoserverConfig.Styles.get_style(conn, "workspace_name", "style_name")
{:ok, sld_xml} = GeoserverConfig.Styles.get_style(conn, nil, "global_style")

# Save to disk (no connection needed)
{:ok, %{file_path: path, size: bytes}} = GeoserverConfig.Styles.write_sld_file("/tmp/style.sld", sld_xml)
```

**Create SLD or CSS styles with auto-detection:**

```elixir
# SLD style (explicit format)
{:ok, "sld_style"} = GeoserverConfig.Styles.create_style(conn, %{
  name: "sld_style",
  content: "<StyledLayerDescriptor>...</StyledLayerDescriptor>",
  format: :sld,
  workspace: "workspace_name"
})

# CSS style (explicit format)
{:ok, "css_style"} = GeoserverConfig.Styles.create_style(conn, %{
  name: "css_style",
  content: "* { stroke: red; fill: blue; }",
  format: :css
})

# Auto-detect format from filename
{:ok, "auto_style"} = GeoserverConfig.Styles.create_style(conn, %{
  name: "auto_style",
  content: "* { stroke: red; }",
  filename: "style.css"  # Auto-detects CSS format
})

# Global style (omit workspace)
{:ok, "global_style"} = GeoserverConfig.Styles.create_style(conn, %{
  name: "global_style",
  content: "<StyledLayerDescriptor>...</StyledLayerDescriptor>"
})
```

**Update styles (supports both SLD and CSS):**

```elixir
{:ok, "my_style"} = GeoserverConfig.Styles.update_style(conn, %{
  name: "my_style",
  content: "<StyledLayerDescriptor>...</StyledLayerDescriptor>",
  format: :sld,
  workspace: "workspace_name"
})

# Update CSS style
{:ok, "css_style"} = GeoserverConfig.Styles.update_style(conn, %{
  name: "css_style",
  content: "* { stroke: blue; }",
  format: :css
})
```

**Copy styles between workspaces:**

```elixir
# Copy from global to workspace
{:ok, "ws_style"} = GeoserverConfig.Styles.copy_style(
  conn,
  "global_style",
  nil,  # source workspace (nil = global)
  "ws_style",  # target name
  "target_workspace"  # target workspace
)

# Copy between workspaces
{:ok, "copied_style"} = GeoserverConfig.Styles.copy_style(
  conn,
  "source_style",
  "source_workspace",
  "copied_style",
  "target_workspace"
)
```

**Move styles between workspaces:**

```elixir
# Move from workspace to global
{:ok, "moved_style"} = GeoserverConfig.Styles.move_style(
  conn,
  "style_name",
  "source_workspace",
  nil  # target workspace (nil = global)
)

# Move between workspaces with purge
{:ok, "moved_style"} = GeoserverConfig.Styles.move_style(
  conn,
  "style_name",
  "source_workspace",
  "target_workspace",
  purge: true  # Purge original files
)
```

**Delete styles:**

```elixir
# Delete workspace style with purge
{:ok, "my_style"} = GeoserverConfig.Styles.delete_style(
  conn, 
  "my_style", 
  "workspace_name", 
  purge: true, 
  recurse: true
)

# Delete global style
{:ok, "my_style"} = GeoserverConfig.Styles.delete_style(conn, "my_style")
```

## Assign Style to Layer

Verifies the style exists before assigning it:

```elixir
# Style from the same or global scope
{:ok, msg} = GeoserverConfig.StyleAssignToLayer.assign_style_to_layer(
  conn,
  "workspace_name",
  "layer_name",
  "style_name"
)

# Style from a specific workspace
{:ok, msg} = GeoserverConfig.StyleAssignToLayer.assign_style_to_layer(
  conn,
  "workspace_name",
  "layer_name",
  "style_name",
  "style_workspace"
)
```

## Layer Group Operations

```elixir
{:ok, groups} = GeoserverConfig.LayerGroups.list_layer_groups(conn)

# Create from XML or a map
{:ok, _} = GeoserverConfig.LayerGroups.create_layer_group(conn, xml_string)
{:ok, _} = GeoserverConfig.LayerGroups.create_layer_group(conn, %{"layerGroup" => %{"name" => "my-group"}})

# Update
{:ok, _} = GeoserverConfig.LayerGroups.update_layer_group(conn, "my-group", updated_xml)

# Add / remove layers
{:ok, _} = GeoserverConfig.LayerGroups.add_layer_to_group(conn, "my-group", "ws:layer1", "ws:style1")
{:ok, _} = GeoserverConfig.LayerGroups.remove_layer_from_group(conn, "my-group", "ws:layer1")

{:ok, "my-group"} = GeoserverConfig.LayerGroups.delete_layer_group(conn, "my-group")
```

## Error Handling

All functions return tagged tuples. Pattern match to handle each case:

```elixir
case GeoserverConfig.Workspaces.fetch_workspaces(conn) do
  {:ok, workspaces} ->
    IO.inspect(workspaces)

  {:error, {:http_error, status, body}} ->
    IO.puts("GeoServer returned #{status}: #{inspect(body)}")

  {:error, {:not_found, name}} ->
    IO.puts("#{name} does not exist")

  {:error, {:request_failed, reason}} ->
    IO.puts("Transport error: #{inspect(reason)}")
end
```

## Notes

- Use `file://` prefix for local file paths passed to GeoServer (e.g. `file:///data/dem.tif`)
- Use `cog://` prefix for Cloud Optimized GeoTIFFs served over HTTP or S3
- Coverage layer creation requires bounding box and CRS information matching the source raster
- Feature types (vector layers) support comprehensive metadata including bounding boxes and keywords
- Styles can be scoped globally or per workspace; pass `nil` as workspace for global styles
- Style format (SLD vs CSS) is auto-detected from content or can be specified explicitly
- `recurse: true` / `purge: true` options cascade deletes to dependent resources
- Style copy/move operations preserve all style content and metadata
- PostGIS datastores support comprehensive connection pooling and performance parameters

## License

MIT License
