defmodule GeoserverConfig.StylesTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.Styles

  describe "create_style/2 with CSS support" do
    test "creates CSS style with explicit format" do
      Req.Test.stub(__MODULE__, fn conn ->
        # Verify CSS content type header
        assert String.contains?(
                 conn.req_headers |> Enum.find(fn {k, _} -> k == "content-type" end) |> elem(1),
                 "geocss+css"
               )

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      css_content = "* { stroke: red; fill: blue; }"

      opts = %{
        name: "my_css_style",
        content: css_content,
        format: :css
      }

      assert {:ok, "my_css_style"} = Styles.create_style(test_conn(__MODULE__), opts)
    end

    test "creates SLD style with explicit format" do
      Req.Test.stub(__MODULE__, fn conn ->
        # Verify SLD content type header
        assert String.contains?(
                 conn.req_headers |> Enum.find(fn {k, _} -> k == "content-type" end) |> elem(1),
                 "sld+xml"
               )

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      sld_content = "<StyledLayerDescriptor><Name>test</Name></StyledLayerDescriptor>"

      opts = %{
        name: "my_sld_style",
        content: sld_content,
        format: :sld
      }

      assert {:ok, "my_sld_style"} = Styles.create_style(test_conn(__MODULE__), opts)
    end

    test "auto-detects CSS format from filename" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert String.contains?(
                 conn.req_headers |> Enum.find(fn {k, _} -> k == "content-type" end) |> elem(1),
                 "geocss+css"
               )

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      opts = %{
        name: "auto_detect_style",
        content: "* { stroke: red; }",
        filename: "style.css"
      }

      assert {:ok, "auto_detect_style"} = Styles.create_style(test_conn(__MODULE__), opts)
    end

    test "auto-detects SLD format from filename" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert String.contains?(
                 conn.req_headers |> Enum.find(fn {k, _} -> k == "content-type" end) |> elem(1),
                 "sld+xml"
               )

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      opts = %{
        name: "auto_detect_sld",
        content: "<StyledLayerDescriptor><Name>test</Name></StyledLayerDescriptor>",
        filename: "style.sld"
      }

      assert {:ok, "auto_detect_sld"} = Styles.create_style(test_conn(__MODULE__), opts)
    end

    test "returns error for missing required parameters" do
      assert {:error, "Missing required parameter :name"} =
               Styles.create_style(test_conn(__MODULE__), %{content: "content"})

      assert {:error, "Missing required parameter :content"} =
               Styles.create_style(test_conn(__MODULE__), %{name: "test"})
    end

    test "returns error for invalid format" do
      opts = %{
        name: "test",
        content: "content",
        format: :invalid
      }

      assert {:error, "Invalid format. Use :sld or :css"} =
               Styles.create_style(test_conn(__MODULE__), opts)
    end

    test "returns {:error, {:http_error, status, body}} on non-2xx" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal error"}))
      end)

      assert {:error, {:http_error, 500, _}} =
               Styles.create_style(test_conn(__MODULE__), %{
                 name: "my_style",
                 content: "<StyledLayerDescriptor/>",
                 format: :sld
               })
    end
  end

  describe "update_style/2 with CSS support" do
    test "updates CSS style" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert String.contains?(
                 conn.req_headers |> Enum.find(fn {k, _} -> k == "content-type" end) |> elem(1),
                 "geocss+css"
               )

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      opts = %{
        name: "existing_style",
        content: "* { stroke: blue; }",
        format: :css,
        workspace: "test_workspace"
      }

      assert {:ok, "existing_style"} = Styles.update_style(test_conn(__MODULE__), opts)
    end

    test "returns error for missing required parameters in update" do
      assert {:error, "Missing required parameter :name"} =
               Styles.update_style(test_conn(__MODULE__), %{content: "content"})

      assert {:error, "Missing required parameter :content"} =
               Styles.update_style(test_conn(__MODULE__), %{name: "test"})
    end

    test "returns {:error, {:http_error, status, body}} on non-2xx" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Styles.update_style(test_conn(__MODULE__), %{
                 name: "missing_style",
                 content: "<StyledLayerDescriptor/>",
                 format: :sld
               })
    end
  end

  describe "delete_style/4" do
    test "returns {:ok, style_name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "roads_red"} = Styles.delete_style(test_conn(__MODULE__), "roads_red")
    end

    test "returns {:skipped, style_name} on 404 (idempotent delete)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:skipped, "roads_red"} = Styles.delete_style(test_conn(__MODULE__), "roads_red")
    end

    test "returns {:error, {:http_error, status, body}} on other failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Server error"}))
      end)

      assert {:error, {:http_error, 500, _}} =
               Styles.delete_style(test_conn(__MODULE__), "roads_red")
    end
  end

  describe "copy_style/6" do
    test "copies style from global to workspace" do
      # Stub get_style call
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/geoserver/rest/styles/source_style.sld" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/vnd.ogc.sld+xml")
            |> Plug.Conn.send_resp(
              200,
              "<StyledLayerDescriptor><Name>source</Name></StyledLayerDescriptor>"
            )

          "/geoserver/rest/workspaces/target_ws/styles" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(201, "")
        end
      end)

      assert {:ok, "target_style"} =
               Styles.copy_style(
                 test_conn(__MODULE__),
                 "source_style",
                 nil,
                 "target_style",
                 "target_ws"
               )
    end

    test "copies style from workspace to global" do
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/geoserver/rest/workspaces/source_ws/styles/source_style.sld" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/vnd.ogc.sld+xml")
            |> Plug.Conn.send_resp(
              200,
              "<StyledLayerDescriptor><Name>source</Name></StyledLayerDescriptor>"
            )

          "/geoserver/rest/styles" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(201, "")
        end
      end)

      assert {:ok, "target_style"} =
               Styles.copy_style(
                 test_conn(__MODULE__),
                 "source_style",
                 "source_ws",
                 "target_style",
                 nil
               )
    end

    test "returns error when source style not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:error, {:not_found, "source_style"}} =
               Styles.copy_style(
                 test_conn(__MODULE__),
                 "source_style",
                 nil,
                 "target_style",
                 "target_ws"
               )
    end
  end

  describe "move_style/5" do
    test "returns error when copy fails during move" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:error, {:not_found, "source_style"}} =
               Styles.move_style(
                 test_conn(__MODULE__),
                 "source_style",
                 "source_ws",
                 "target_ws"
               )
    end
  end
end
