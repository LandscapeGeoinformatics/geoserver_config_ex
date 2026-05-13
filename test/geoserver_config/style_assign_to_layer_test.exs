defmodule GeoserverConfig.StyleAssignToLayerTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.StyleAssignToLayer

  describe "assign_style_to_layer/5" do
    test "assigns a global style to a layer" do
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/geoserver/rest/styles/my_style.json" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "")

          "/geoserver/rest/workspaces/my_workspace/layers/my_layer" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "")
        end
      end)

      assert {:ok, message} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 "my_style"
               )

      assert message =~ "successfully assigned"
    end

    test "assigns a workspace-scoped style to a layer" do
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/geoserver/rest/workspaces/style_ws/styles/my_style.json" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "")

          "/geoserver/rest/workspaces/my_workspace/layers/my_layer" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "")
        end
      end)

      assert {:ok, message} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 "my_style",
                 "style_ws"
               )

      assert message =~ "successfully assigned"
    end

    test "unassigns when style_name is nil" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, message} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 nil
               )

      assert message =~ "removed"
    end

    test "unassigns when style_name is empty string" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, message} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 ""
               )

      assert message =~ "removed"
    end

    test "returns error when global style does not exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:error, message} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 "missing_style"
               )

      assert message =~ "does not exist globally"
    end

    test "returns error when workspace style does not exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:error, message} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 "missing_style",
                 "style_ws"
               )

      assert message =~ "does not exist in workspace"
    end

    test "returns error on PUT failure during assignment" do
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/geoserver/rest/styles/my_style.json" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "")

          "/geoserver/rest/workspaces/my_workspace/layers/my_layer" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Server error"}))
        end
      end)

      assert {:error, {:http_error, 500, _}} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 "my_style"
               )
    end

    test "returns :unauthorized on 401 during assignment" do
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/geoserver/rest/styles/my_style.json" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "")

          "/geoserver/rest/workspaces/my_workspace/layers/my_layer" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(401, "")
        end
      end)

      assert {:error, :unauthorized} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer",
                 "my_style"
               )
    end

    test "returns {:error, {:http_error, status, _}} on unexpected status during style check" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, "")
      end)

      assert {:error, {:http_error, 503, _}} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__), "my_workspace", "my_layer", "my_style"
               )
    end

    test "returns {:error, {:request_failed, _}} on transport error during style check" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__), "my_workspace", "my_layer", "my_style"
               )
    end

    test "accepts 201 as success for style assignment PUT" do
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/geoserver/rest/styles/my_style.json" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "")

          _ ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(201, "")
        end
      end)

      assert {:ok, message} =
               StyleAssignToLayer.assign_style_to_layer(
                 test_conn(__MODULE__), "my_workspace", "my_layer", "my_style"
               )

      assert message =~ "successfully assigned"
    end
  end

  describe "unassign_style_from_layer/3" do
    test "removes default style from a layer" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, message} =
               StyleAssignToLayer.unassign_style_from_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer"
               )

      assert message =~ "removed"
    end

    test "returns :unauthorized on 401" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, "")
      end)

      assert {:error, :unauthorized} =
               StyleAssignToLayer.unassign_style_from_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer"
               )
    end

    test "returns {:error, {:http_error, status, body}} on other failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Server error"}))
      end)

      assert {:error, {:http_error, 500, _}} =
               StyleAssignToLayer.unassign_style_from_layer(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_layer"
               )
    end
  end
end
