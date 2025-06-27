```markdown
# GeoServer Configuration Elixir Client

This Elixir application provides a convenient way to interact with GeoServer's REST API to manage workspaces, datastores, and coveragestores.

## Prerequisites

- Elixir 1.12+ installed
- Req HTTP client (included in mix.exs dependencies)
- GeoServer instance with REST API enabled
- Valid GeoServer credentials

## Setup

1. Clone the repository
2. Install dependencies:

   ```bash
   mix deps.get
   ```
3. Set environment variables:
   ```bash
   export GEOSERVER_USERNAME="your_username"
   export GEOSERVER_PASSWORD="your_password"
   export GEOSERVER_BASE_URL="your_geoserver_base_url"
   ```

## Workspace Operations

### List All Workspaces
```elixir
GeoserverConfig.Workspaces.fetch_workspaces()
```

### Create a Workspace
```elixir
GeoserverConfig.Workspaces.create_workspace("new_workspace_name")
```

### Update a Workspace (ineffective - renaming is unauthorized)
```elixir
GeoserverConfig.Workspaces.update_workspace("old_name", "new_name")
```

### Delete a Workspace
```elixir
GeoserverConfig.Workspaces.delete_workspace("workspace_to_delete")
```

## Datastore Operations

### List Datastores in a Workspace
```elixir
GeoserverConfig.Datastores.list_datastores("workspace_name")
```

### Create Datastore (Shapefile)
```elixir
GeoserverConfig.Datastores.create_datastore(
  "workspace_name",
  "datastore_name",
  "shapefile",
  %{url: "file:///path/to/shapefile_directory"}
)
```

### Create Datastore (PostGIS)
```elixir
GeoserverConfig.Datastores.create_datastore(
  "workspace_name",
  "datastore_name",
  "postgis",
  %{
    host: "localhost",
    port: 5432,
    database: "db_name",
    user: "db_user",
    passwd: "db_password"
  }
)
```

### Create Datastore (GeoPackage)
```elixir
GeoserverConfig.Datastores.create_datastore(
  "workspace_name",
  "datastore_name",
  "geopkg",
  %{database: "file:///path/to/file.gpkg"}
)
```

### Update Datastore
```elixir
GeoserverConfig.Datastores.update_datastore(
  "workspace_name",
  "old_datastore_name",
  "shapefile", # or "postgis", "geopkg"
  %{
    description: "New description",
    url: "file:///new/path" # or PostGIS/GeoPackage params
  }
)
```

### Delete Datastore
```elixir
GeoserverConfig.Datastores.delete_datastore(
  "workspace_name",
  "datastore_name",
  true # set to false if you don't want recursive delete
)
```

## Coveragestore Operations

### List Coveragestores in a Workspace
```elixir
GeoserverConfig.Coveragestores.list_coveragestores("workspace_name")
```

### Create Coveragestore (Local GeoTIFF)
```elixir
GeoserverConfig.Coveragestores.create_coveragestore(
  "workspace_name",
  "coveragestore_name",
  "file:///path/to/geotiff.tif",
  "Optional description"
)
```

### Create COG GeoTIFF Coverage Store in GeoServer
```
GeoserverConfig.Coveragestores.create_coveragestore(
  "workspace_name",
  "coveragestore_name",
  "cog://https://path.to/your/cog_geotiff_cog.tif",
  "Description of your coverage store",
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
```

### Update Coveragestore
```elixir
GeoserverConfig.Coveragestores.update_coveragestore(
  "workspace_name",
  "store_name",
  %{
    type: "GeoTIFF",
    enabled: true,
    url: "file:///new/path/to/file.tif",
    description: "Updated description"
  }
)
```

### Delete Coveragestore
```elixir
GeoserverConfig.Coveragestores.delete_coveragestore(
  "workspace_name",
  "coveragestore_name"
)
```

## Coverage Layer Operations

### List Coverages

```elixir
GeoserverConfig.list_coverages("workspace_name", "coveragestore_name")
```

### Create Coverage Layer

```elixir
GeoserverConfig.Coverages.create_coverage(
  "workspace_name",
  "coveragestore_name",
  "coverage_layer_name",
  %{
    title: "Layer Title",
    description: "Layer Description",
    abstract: "Abstract info",
    srs: "EPSG:3301",
    native_crs: "EPSG:3301",
    native_bbox: %{minx: ..., maxx: ..., miny: ..., maxy: ...},
    latlon_bbox: %{minx: ..., maxx: ..., miny: ..., maxy: ...},
    grid: %{
      dimension: [width, height],
      transform: [scale_x, 0.0, translate_x, 0.0, scale_y, translate_y]
    },
    metadata: %{
      "cacheAgeMax" => 3600,
      "cachingEnabled" => true
    }
  },
  "file:///path/to/geotiff.tif"
)
```

### Delete Coverage Layer

```elixir
GeoserverConfig.delete_coverage("workspace_name", "coveragestore_name", "coverage_layer_name", "true")
```

## Style Operations

### List All Styles
```elixir
GeoserverConfig.list_styles()
```

### List Workspace Specific Styles
```elixir
GeoserverConfig.list_styles_workspace_specific("workspace_name")
```

### Create Style
```elixir
GeoserverConfig.Styles.create_style(%{
  name: "style_name",
  sld_content: "<StyledLayerDescriptor>...</StyledLayerDescriptor>",
  filename: "style.sld",
  # Optional: workspace: "workspace_name"
})
```

### Update Style
```elixir
GeoserverConfig.Styles.update_style(%{
  name: "style_name",
  sld_content: "<UpdatedSLD>...</UpdatedSLD>",
  filename: "updated_style.sld",
  workspace: "workspace_name"
})
```

### Delete Style
```elixir
GeoserverConfig.delete_style("style_name", "workspace_name", recurse: true)
```

## Assign Style to Layer
```elixir
GeoserverConfig.assign_style_to_layer(
  "workspace_name",
  "layer_name",
  "style_name",
  "workspace_name" # style workspace if applicable
)
```


## Error Handling

All functions return either:
- Success tuple `{:ok, message}` for 200/201 responses
- Error tuple `{:error, reason}` for failures

You can pattern match on these responses to handle success/failure cases.

## Configuration

The application uses the following environment variables:
- `GEOSERVER_USERNAME`: Your GeoServer username
- `GEOSERVER_PASSWORD`: Your GeoServer password
- `GEOSERVER_BASE_URL`: Base URL of your GeoServer instance

## Notes

1. For file paths, use `file://` prefix for GeoServer compatibility
2. When deleting resources, set `recurse=true` to delete all dependent resources
3. Coverage layer creation requires detailed bounding box and CRS info
4. Supports both local and cloud-based COG files (cog:// scheme)
5. Compatible with styles scoped globally or per workspace

## License

[MIT License](LICENSE)
```

This README provides:
1. Clear setup instructions
2. Comprehensive usage examples for all CRUD operations
3. Error handling information
4. Configuration details
5. Notes about important considerations
