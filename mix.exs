defmodule GeoserverConfig.MixProject do
  use Mix.Project

  def project do
    [
      app: :geoserver_config,
      version: "0.3.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "An Elixir client for the GeoServer REST API.",
      package: package(),
      deps: deps(),
      name: "GeoserverConfig",
      source_url: "https://github.com/LandscapeGeoinformatics/geoserver_config_ex",
      docs: [
        main: "GeoserverConfig",
        extras: ["README.md"]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Alexander Kmoch", "Zeshan Hyder"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/LandscapeGeoinformatics/geoserver_config_ex"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:sweet_xml, "~> 0.7.3"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:plug, "~> 1.0", only: :test}
    ]
  end
end
