# geoserver_config — Agent Usage Rules

## Overview

`geoserver_config` is an Elixir client for the GeoServer REST API. It manages
workspaces, datastores, feature types, coverage stores, coverages, styles,
style assignments, and layer groups.

All functions accept a `%GeoserverConfig.Connection{}` struct as the first argument
and return `{:ok, result} | {:error, reason}` tuples.

## Dependencies

- `req ~> 0.5` — HTTP client
- `sweet_xml ~> 0.7.3` — XML parsing
- `jason ~> 1.4` — JSON encoding

## Connection

Build one connection and reuse it:

```elixir
conn = GeoserverConfig.Connection.new(base_url, username, password)
# or from env vars:
conn = GeoserverConfig.Connection.from_env()
# or with custom prefix:
conn = GeoserverConfig.Connection.from_env(prefix: "STAGING_GEOSERVER")
```

The `%Connection{}` struct has keys `:base_url`, `:username`, `:password` plus
an optional `:plug` field for test stubs.

## Return-value conventions

Every public function returns a tagged tuple:

| Pattern | Meaning |
|---|---|
| `{:ok, result}` | Success |
| `{:error, {:http_error, status, body}}` | GeoServer HTTP error |
| `{:error, {:request_failed, reason}}` | Transport error (timeout, connection refused) |
| `{:error, {:not_found, name}}` | Resource not found (some delete functions) |
| `{:error, :unexpected_format, body}` | Response body didn't match expected shape |
| `{:skipped, name}` | Delete of already-missing resource (idempotent) |

**List results** are normalised: GeoServer returns a single map when only one item
exists; the library always returns `{:ok, [item]}` (never a bare map).

List results contain maps with `"name"` and `"href"` keys. To extract just names:

```elixir
names = Enum.map(results, & &1["name"])
```

## Module structure

- `GeoserverConfig` — facade, delegates to submodules
- `GeoserverConfig.Connection` — connection struct
- `GeoserverConfig.Workspaces` — workspace CRUD
- `GeoserverConfig.Datastores` — datastore CRUD (shapefile, geopkg, postgis, wfs)
- `GeoserverConfig.FeatureTypes` — vector layer CRUD
- `GeoserverConfig.Coveragestores` — coverage store CRUD
- `GeoserverConfig.Coverages` — raster layer CRUD
- `GeoserverConfig.Styles` — style CRUD + copy/move/write
- `GeoserverConfig.StyleAssignToLayer` — assign/unassign styles to layers
- `GeoserverConfig.LayerGroups` — layer group CRUD + add/remove layers

## Datastores

```elixir
# Shapefile
GeoserverConfig.Datastores.create_datastore(conn, ws, name, "shapefile",
  %{url: "file:///absolute/path/to/dir"})

# GeoPackage
GeoserverConfig.Datastores.create_datastore(conn, ws, name, "geopkg",
  %{database: "file:///path/to/file.gpkg"})

# PostGIS
GeoserverConfig.Datastores.create_datastore(conn, ws, name, "postgis", %{
  host: "localhost", port: 5432, database: "db",
  user: "user", passwd: "pass", schema: "public"
})
```

**Key rule**: connection params use atom keys (`:host`, `:database`) for required
fields. Optional PostGIS params use string keys (`"max connections"`, `"Loose bbox"`).

**File paths**: use `file:///` (three slashes) for absolute Unix paths or
`file://<relative>` for paths relative to GeoServer's data directory.

## Feature types (vector layers)

```elixir
# List configured (default)
{:ok, types} = GeoserverConfig.list_featuretypes(conn, ws, store)

# List available (unpublished)
{:ok, available} = GeoserverConfig.list_featuretypes(conn, ws, store, :available)

# Create
GeoserverConfig.create_featuretype(conn, ws, store, name, %{
  title: "My Layer", srs: "EPSG:4326", enabled: true
})

# Update with bbox recalculation
GeoserverConfig.update_featuretype(conn, ws, store, name,
  %{title: "New Title"}, "nativebbox,latlonbbox")
```

The `:available` listing works for PostGIS and GeoPackage stores. Shapefile
stores require a known layer name to create a feature type — GeoServer's REST API
doesn't support creating feature types from shapefiles without specifying
attributes.

## Coverage stores and coverages

```elixir
# Local GeoTIFF store
GeoserverConfig.Coveragestores.create_coveragestore(conn, ws, name,
  "file:///path/to/dem.tif", "Optional description")

# COG store
GeoserverConfig.Coveragestores.create_coveragestore(conn, ws, name,
  "cog://https://example.com/data.tif", "COG from HTTP", %{
    metadata: %{"entry" => %{
      "@key" => "CogSettings.Key",
      "cogSettings" => %{"useCachingStream" => false, "rangeReaderSettings" => "HTTP"}
    }},
    disableOnConnFailure: false
  })

# Create coverage layer (requires bbox + grid + CRS)
GeoserverConfig.Coverages.create_coverage(conn, ws, cov_store, layer_name, %{
  title: "DEM", srs: "EPSG:3301", native_crs: "EPSG:3301",
  native_bbox: %{minx: 369000.0, maxx: 740000.0, miny: 6377000.0, maxy: 6635000.0},
  latlon_bbox: %{minx: 21.664, maxx: 28.275, miny: 57.471, maxy: 59.831},
  grid: %{dimension: [3710, 2580], transform: [10.0, 0.0, 369000.0, 0.0, -10.0, 6635000.0]}
}, "file:///path/to/dem.tif")
```

**Coverage creation requires** `:title`, `:srs`, `:native_bbox`, `:latlon_bbox`,
and `:grid` parameters matching the source raster. Missing any of these will
cause a GeoServer 500 error.

## Styles

```elixir
# Create workspace style
GeoserverConfig.Styles.create_style(conn, %{
  name: "my_style", content: sld_xml, format: :sld, workspace: "my_ws"
})

# Global style (omit workspace)
GeoserverConfig.Styles.create_style(conn, %{
  name: "global_style", content: sld_xml
})

# Copy between workspaces
GeoserverConfig.Styles.copy_style(conn, "source", "source_ws",
  "target", "target_ws")

# Write SLD to local file (no connection needed)
GeoserverConfig.Styles.write_sld_file("/tmp/style.sld", sld_xml)
```

**Key difference**: `create_style/2` and `update_style/2` take a **map** as opts
(`%{name: ..., content: ...}`). `delete_style/4`, `copy_style/6`, and
`move_style/5` take a **keyword list** as opts (`[recurse: true, purge: true]`).

Style format (`:sld` vs `:css`) is auto-detected from content or filename.
Pass `format: :sld` or `format: :css` explicitly to override.

## Style assignment and unassignment

```elixir
# Assign
GeoserverConfig.StyleAssignToLayer.assign_style_to_layer(
  conn, "ws", "layer_name", "style_name", "style_workspace")

# Unassign (remove default style)
GeoserverConfig.unassign_style_from_layer(conn, "ws", "layer_name")

# Or pass nil/"" as style_name to assign_style_to_layer
GeoserverConfig.assign_style_to_layer(conn, "ws", "layer_name", nil)
```

## Layer groups

```elixir
# Create from XML or JSON map
GeoserverConfig.LayerGroups.create_layer_group(conn, xml_string)
GeoserverConfig.LayerGroups.create_layer_group(conn, %{"layerGroup" => %{...}})

# Add/remove layers — the library automatically maintains the layer:style parity
# that GeoServer requires (equal numbers of publishables and styles)
GeoserverConfig.LayerGroups.add_layer_to_group(conn, "group", "ws:layer", "ws:style")
GeoserverConfig.LayerGroups.remove_layer_from_group(conn, "group", "ws:layer")
```

When creating or updating layer groups, ensure the number of `<published>` entries
equals the number of `<style>` entries. The `add_layer_to_group` and
`remove_layer_from_group` functions handle this automatically.

## Cleanup patterns

Always delete in reverse dependency order:

1. Layer groups
2. Styles (with `recurse: true` to unassign from layers)
3. Coverages (raster layers)
4. Coverage stores
5. Feature types (vector layers)
6. Datastores
7. Workspaces

Use `recurse: true` on deletes to cascade removal of dependent resources:

```elixir
GeoserverConfig.Datastores.delete_datastore(conn, ws, store, true)
```

Delete operations return `{:skipped, name}` for 404 (already deleted) — treat
this as success. For robust cleanup, swallow errors:

```elixir
defp swallow_errors(fun) do
  case fun.() do
    {:error, _} -> :ok
    ok -> ok
  end
end
```

## Error handling

Always pattern-match on the tagged tuple, handling all error shapes:

```elixir
case GeoserverConfig.Workspaces.fetch_workspaces(conn) do
  {:ok, workspaces} -> workspaces
  {:error, {:http_error, status, body}} -> handle_http_error(status, body)
  {:error, {:request_failed, reason}} -> handle_transport_error(reason)
end
```

## Notes

- `file:///` (three slashes) for absolute Unix file paths to GeoServer
- `cog://` prefix for Cloud Optimized GeoTIFFs
- Feature type `params` and coverage `params` use **atom keys** (struct-style dot access)
- Datastore connection params use **atom keys** for required fields, **string keys** for optional ones
- Coverage create requires `:grid`, `:native_bbox`, and `:latlon_bbox` — use `gdalinfo` on the source file to get correct values
