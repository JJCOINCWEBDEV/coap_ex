defmodule CoAP.MixProject do
  use Mix.Project

  def project do
    [
      app: :coap_parser,
      version: "0.1.0",
      elixir: "~> 1.10",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end
end
