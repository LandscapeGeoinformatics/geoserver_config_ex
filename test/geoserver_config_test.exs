defmodule GeoserverConfigTest do
  use ExUnit.Case
  doctest GeoserverConfig

  test "greets the world" do
    assert GeoserverConfig.hello() == :world
  end
end
