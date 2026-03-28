defmodule GeoserverConfig do
  @moduledoc """
  Top-level API module for interacting with a GeoServer instance via REST.

  All functions require a `GeoserverConfig.Connection` as their first argument.
  Build one with `GeoserverConfig.Connection.new/3`, `from_env/1`, or
  `from_application_env/2`.

  ## Quick start

      conn = GeoserverConfig.Connection.from_env()
      {:ok, workspaces} = GeoserverConfig.fetch_workspaces(conn)

  ## Functionality

    - Manage workspaces
    - Handle datastores (PostGIS, GeoPackage, Shapefile, WFS)
    - Manage coverage stores and coverages (GeoTIFF, COGs)
    - Manage styles (SLD-based)
    - Assign styles to layers
    - Manage layer groups
  """

  alias GeoserverConfig.Connection
  alias GeoserverConfig.{Workspaces, Datastores, Coveragestores, Coverages}
  alias GeoserverConfig.{Styles, StyleAssignToLayer, LayerGroups, FeatureTypes}

  # Workspaces
  defdelegate fetch_workspaces(conn), to: Workspaces
  defdelegate create_workspace(conn, workspace_name), to: Workspaces
  defdelegate delete_workspace(conn, workspace_name), to: Workspaces
  defdelegate update_workspace(conn, old_workspace_name, new_workspace_name), to: Workspaces

  # Feature types (vector layers) - also available under FeatureTypes module
  def list_featuretypes(conn, workspace, datastore, list) do
    FeatureTypes.list_featuretypes(conn, workspace, datastore, list)
  end

  def list_featuretypes(conn, workspace, datastore) do
    FeatureTypes.list_featuretypes(conn, workspace, datastore, :configured)
  end

  def create_featuretype(conn, workspace, datastore, featuretype_name, params) do
    FeatureTypes.create_featuretype(conn, workspace, datastore, featuretype_name, params)
  end

  def create_featuretype(conn, workspace, datastore, featuretype_name) do
    FeatureTypes.create_featuretype(conn, workspace, datastore, featuretype_name, %{})
  end

  def update_featuretype(conn, workspace, datastore, featuretype_name, params, recalculate) do
    FeatureTypes.update_featuretype(conn, workspace, datastore, featuretype_name, params, recalculate)
  end

  def update_featuretype(conn, workspace, datastore, featuretype_name, params) do
    FeatureTypes.update_featuretype(conn, workspace, datastore, featuretype_name, params, nil)
  end

  def update_featuretype(conn, workspace, datastore, featuretype_name) do
    FeatureTypes.update_featuretype(conn, workspace, datastore, featuretype_name, %{}, nil)
  end

  def delete_featuretype(conn, workspace, datastore, featuretype_name, recurse) do
    FeatureTypes.delete_featuretype(conn, workspace, datastore, featuretype_name, recurse)
  end

  def delete_featuretype(conn, workspace, datastore, featuretype_name) do
    FeatureTypes.delete_featuretype(conn, workspace, datastore, featuretype_name, false)
  end

  # Datastores
  defdelegate list_datastores(conn, workspace), to: Datastores
  defdelegate create_datastore(conn, workspace, name, type, connection_params), to: Datastores
  defdelegate update_datastore(conn, workspace, datastore_name, datastore_type, connection_params), to: Datastores

  def delete_datastore(conn, workspace, datastore_name, recurse \\ false) do
    Datastores.delete_datastore(conn, workspace, datastore_name, recurse)
  end



  # Coverage stores
  defdelegate list_coveragestores(conn, workspace), to: Coveragestores
  defdelegate delete_coveragestore(conn, workspace, name), to: Coveragestores
  defdelegate update_coveragestore(conn, workspace, store_name, updated_params), to: Coveragestores

  def create_coveragestore(conn, workspace, store_name, geotiff_path, description \\ "", opts \\ %{}) do
    Coveragestores.create_coveragestore(conn, workspace, store_name, geotiff_path, description, opts)
  end

  # Coverages
  defdelegate list_coverages(conn, workspace, coverage_store), to: Coverages
  defdelegate create_coverage(conn, workspace, coverage_store, coverage_name, params, file_path), to: Coverages

  def delete_coverage(conn, workspace, coverage_store, coverage_name, recurse \\ false) do
    Coverages.delete_coverage(conn, workspace, coverage_store, coverage_name, recurse)
  end

  # Styles
  defdelegate list_styles(conn), to: Styles
  defdelegate list_styles_workspace_specific(conn, workspace), to: Styles
  defdelegate get_style(conn, workspace, style_name), to: Styles
  defdelegate write_sld_file(style_file_path, sld_content), to: Styles
  defdelegate create_style(conn, opts), to: Styles
  defdelegate update_style(conn, opts), to: Styles

  def delete_style(%Connection{} = conn, style_name, workspace \\ nil, opts \\ []) do
    Styles.delete_style(conn, style_name, workspace, opts)
  end

  # Style assignment
  def assign_style_to_layer(%Connection{} = conn, workspace, layer_name, style_name, style_workspace \\ nil) do
    StyleAssignToLayer.assign_style_to_layer(conn, workspace, layer_name, style_name, style_workspace)
  end

  # Layer groups
  defdelegate list_layer_groups(conn), to: LayerGroups
  defdelegate create_layer_group(conn, body), to: LayerGroups
  defdelegate update_layer_group(conn, name, body), to: LayerGroups
  defdelegate delete_layer_group(conn, name), to: LayerGroups
  defdelegate remove_layer_from_group(conn, group_name, layer_name), to: LayerGroups

  def add_layer_to_group(%Connection{} = conn, group_name, layer_name, style_name \\ nil) do
    LayerGroups.add_layer_to_group(conn, group_name, layer_name, style_name)
  end
end
