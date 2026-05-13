defmodule GeoserverConfig.FeatureTypesTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.FeatureTypes

  describe "list_featuretypes/4" do
    test "returns {:ok, list} when multiple feature types exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "featureTypes" => %{
            "featureType" => [
              %{"name" => "layer_a", "href" => "http://example.com/layer_a"},
              %{"name" => "layer_b", "href" => "http://example.com/layer_b"}
            ]
          }
        })
      end)

      assert {:ok, types} =
               FeatureTypes.list_featuretypes(test_conn(__MODULE__), "my_workspace", "my_store")

      assert length(types) == 2
    end

    test "normalises a single feature type map to a one-element list" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "featureTypes" => %{
            "featureType" => %{
              "name" => "single_layer",
              "href" => "http://example.com/single_layer"
            }
          }
        })
      end)

      assert {:ok, [type]} =
               FeatureTypes.list_featuretypes(test_conn(__MODULE__), "my_workspace", "my_store")

      assert type["name"] == "single_layer"
    end

    test "returns {:ok, []} when there are no feature types" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"featureTypes" => %{}})
      end)

      assert {:ok, []} =
               FeatureTypes.list_featuretypes(test_conn(__MODULE__), "my_workspace", "my_store")
    end

    test "supports different list parameter values" do
      # Test :available
      Req.Test.stub(__MODULE__, fn conn ->
        assert String.contains?(conn.query_string, "list=available")
        Req.Test.json(conn, %{"featureTypes" => %{}})
      end)

      assert {:ok, []} =
               FeatureTypes.list_featuretypes(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 :available
               )

      # Test :all
      Req.Test.stub(__MODULE__, fn conn ->
        assert String.contains?(conn.query_string, "list=all")
        Req.Test.json(conn, %{"featureTypes" => %{}})
      end)

      assert {:ok, []} =
               FeatureTypes.list_featuretypes(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 :all
               )
    end

    test "returns {:error, {:http_error, status, body}} on non-200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               FeatureTypes.list_featuretypes(test_conn(__MODULE__), "my_workspace", "my_store")
    end
  end

  describe "create_featuretype/5" do
    test "returns {:ok, name} on 201" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      params = %{
        title: "My Layer",
        description: "Test layer",
        srs: "EPSG:4326",
        native_bbox: %{minx: -180, maxx: 180, miny: -90, maxy: 90},
        latlon_bbox: %{minx: -180, maxx: 180, miny: -90, maxy: 90}
      }

      assert {:ok, "my_layer"} =
               FeatureTypes.create_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "my_layer",
                 params
               )
    end

    test "returns {:error, trimmed_string} when GeoServer responds 500 with plain text" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(500, "  Layer already exists  ")
      end)

      assert {:error, "Layer already exists"} =
               FeatureTypes.create_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "duplicate_layer",
                 %{}
               )
    end

    test "uses default values when params are minimal" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      assert {:ok, "my_layer"} =
               FeatureTypes.create_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "my_layer",
                 %{}
               )
    end
  end

  describe "update_featuretype/6" do
    test "returns {:ok, name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      params = %{
        title: "Updated Title",
        description: "Updated description"
      }

      assert {:ok, "my_layer"} =
               FeatureTypes.update_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "my_layer",
                 params
               )
    end

    test "adds recalculate parameter when specified" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert String.contains?(conn.query_string, "recalculate=nativebbox")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "my_layer"} =
               FeatureTypes.update_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "my_layer",
                 %{},
                 "nativebbox"
               )
    end
  end

  describe "delete_featuretype/5" do
    test "returns {:ok, name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "my_layer"} =
               FeatureTypes.delete_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "my_layer",
                 true
               )
    end

    test "returns {:ok, name} without recurse flag (default false)" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert String.contains?(conn.query_string, "recurse=false")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "my_layer"} =
               FeatureTypes.delete_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "my_layer"
               )
    end

    test "returns {:skipped, name} on 404 (idempotent delete)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:skipped, "my_layer"} =
               FeatureTypes.delete_featuretype(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "my_layer"
               )
    end
  end
end
