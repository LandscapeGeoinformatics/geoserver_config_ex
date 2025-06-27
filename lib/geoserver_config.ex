defmodule GeoserverConfig do
  @moduledoc """
  Documentation for `GeoserverConfig`.
  """
  alias GeoserverConfig.Coveragestores
  alias GeoserverConfig.{Workspaces, Datastores}
  alias GeoserverConfig.Coverages
  alias GeoserverConfig.Styles
  alias GeoserverConfig.StyleAssignToLayer

  def fetch_workspaces do
    Workspaces.fetch_workspaces()
  end

  # Create a new workspace
  def create_workspace(workspace_name) do
    Workspaces.create_workspace(workspace_name)
  end

  def delete_workspace(workspace_name) do
    Workspaces.delete_workspace(workspace_name)
  end

  def update_workspace(old_workspace_name, new_workspace_name) do
    Workspaces.update_workspace(old_workspace_name, new_workspace_name)
  end

  defdelegate list_datastores(workspace), to: Datastores, as: :list_datastores
  defdelegate create_datastore(workspace, datastore_name, datastore_type, config), to: Datastores
  defdelegate update_datastore(workspace, datastore_name, datastore_type, config), to: Datastores
  defdelegate delete_datastore(workspace, datastore_name), to: Datastores

  defdelegate list_coveragestores(workspace), to: Coveragestores, as: :list_coveragestores
  defdelegate create_coveragestore(workspace, store_name, geotiff_path), to: Coveragestores
  defdelegate update_coveragestore(workspace, store_name, updated_params), to: Coveragestores
  defdelegate delete_coveragestore(workspace, name), to: Coveragestores

  defdelegate create_coverage(workspace, coverage_store, coverage_name, params, file_path), to: Coverages, as: :create_coverage
  defdelegate list_coverages(workspace, coverage_store), to: Coverages
  defdelegate delete_coverage(workspace, coverage_store, coverage_name, recurse), to: Coverages

  defdelegate list_styles, to: Styles
  defdelegate list_styles_workspace_specific(workspace), to: Styles
  defdelegate create_style(opts), to: Styles, as: :create_style
  defdelegate update_style(opts), to: Styles
  defdelegate delete_style(style_name, workspace \\ nil, opts \\ []), to: Styles

  defdelegate assign_style_to_layer(workspace, layer_name, style_name, style_workspace \\ nil), to: StyleAssignToLayer

end
