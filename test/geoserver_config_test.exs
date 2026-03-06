defmodule GeoserverConfigTest do
  use ExUnit.Case, async: true

  # Smoke test: the top-level facade module compiles and its delegations are callable.
  # Functional tests live in test/geoserver_config/*.
  test "module is defined" do
    assert Code.ensure_loaded?(GeoserverConfig)
  end
end
