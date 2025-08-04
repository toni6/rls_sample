defmodule RlsSampleWeb.PageHTMLTest do
  use RlsSampleWeb.ConnCase, async: true

  describe "PageHTML home page" do
    test "GET /", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Phoenix Framework"
      assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
    end

    test "includes navigation links", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Check for external links
      assert response =~ "https://hexdocs.pm/phoenix/overview.html"
      assert response =~ "https://github.com/phoenixframework/phoenix"
      assert response =~ "https://elixirforum.com"
      assert response =~ "https://discord.gg/elixir"
      assert response =~ "https://elixir-slack.community/"
      assert response =~ "https://fly.io/docs/elixir/getting-started/"
    end

    test "includes Phoenix version", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Should display Phoenix version
      phoenix_version = Application.spec(:phoenix, :vsn)
      assert response =~ "v#{phoenix_version}"
    end

    test "includes main navigation elements", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Should include main content sections
      assert response =~ "Guides &amp; Docs"
      assert response =~ "Source Code"
      assert response =~ "Changelog"
    end

    test "is responsive", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Should include responsive CSS classes
      assert response =~ "sm:"
      assert response =~ "lg:"
      assert response =~ "xl:"
      assert response =~ "grid-cols-1"
      assert response =~ "sm:grid-cols-3"
    end

    test "includes accessibility features", %{conn: conn} do
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Should include proper ARIA attributes
      assert response =~ "aria-hidden=\"true\""
      assert response =~ "viewBox="
    end
  end
end
