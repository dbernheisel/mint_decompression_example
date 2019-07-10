defmodule MintDecompression do
  @moduledoc """
  Documentation for MintDecompression.
  """

  alias MintDecompression.ConnectionProcess
  @default_scheme :https

  def get(url, headers \\ []) do
    uri = URI.parse(url)
    uri = %{uri | scheme: String.to_atom(uri.scheme || @default_scheme)}
    uri = %{uri | port: cond do
      !is_nil(uri.port) -> uri.port
      uri.scheme == "http" -> 80
      uri.scheme == "https" -> 443
    end}

    {:ok, pid} = ConnectionProcess.start_link({uri.scheme, uri.host, uri.port})
    result = ConnectionProcess.request(pid, "GET", uri.path, headers)
    ConnectionProcess.close(pid)
    result
  end
end
