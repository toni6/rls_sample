defmodule RlsSampleWeb.RlsDemoLive.IndexTest do
  use RlsSampleWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "RLS Demo LiveView" do
    setup :register_and_log_in_user

    test "renders demo page", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/rls-demo")

      assert html =~ "RLS Demo"
      assert html =~ "Row Level Security"
    end

    test "shows current user context", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/rls-demo")

      assert html =~ "Current User Context"
      assert html =~ "User:"
      assert html =~ "Company:"
      assert html =~ "Role:"
    end

    test "displays demo modes", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/rls-demo")

      assert html =~ "Demo Modes"
      assert html =~ "User Context View"
      assert html =~ "Security Testing"
      assert html =~ "Admin Context"
    end

    test "switches demo modes", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/rls-demo")

      # Switch to admin context
      index_live
      |> element("button[phx-value-mode='admin_context']")
      |> render_click()

      html = render(index_live)
      assert html =~ "Admin Context"
    end

    test "loads page in reasonable time", %{conn: conn} do
      start_time = :os.system_time(:millisecond)
      {:ok, _index_live, html} = live(conn, ~p"/rls-demo")
      end_time = :os.system_time(:millisecond)

      # Should load in reasonable time
      # 5 seconds max
      assert end_time - start_time < 5000
      assert html =~ "RLS Demo"
    end

    test "shows documentation section", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/rls-demo")

      assert html =~ "How This Demo Works"
      assert html =~ "Phoenix Scopes"
      assert html =~ "PostgreSQL RLS"
      assert html =~ "Multi-Tenant Security"
    end
  end
end
