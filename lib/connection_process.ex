defmodule MintDecompression.ConnectionProcess do
  @moduledoc """
  This module is largely copied from Mint's Architecture guide:
  https://github.com/ericmj/mint/blob/d782ed6aaa9d6150a2569d6c77a2c81e5d6b32ec/pages/Architecture.md

  It's then modified to:
  1) when Mint is done with the request, look for a content-encoding header
  2) with that header, try to decompress the body
  3) return the decompressed body instead of the original binary body

  This starts with process_response({:done, request_ref}, state) clause
  Added decompress_data/2 and find_content_encoding/1
  """

  use GenServer
  require Logger

  defstruct [:conn, :stream, :encoding, requests: %{}]

  def start_link({scheme, host, port}) do
    GenServer.start_link(__MODULE__, {scheme, host, port})
  end

  def request(pid, method, path, headers, body \\ nil) do
    GenServer.call(pid, {:request, method, path, headers, body})
  end

  def close(pid) do
    GenServer.call(pid, :close)
  end

  ## Callbacks

  @impl true
  def init({scheme, host, port}) do
    z = :zlib.open()
    :zlib.inflateInit(z, 15 + 32)
    with {:ok, conn} <- Mint.HTTP.connect(scheme, host, port) do
      state = %__MODULE__{stream: z, conn: conn}
      {:ok, state}
    end
  end

  @impl true
  def handle_call({:request, method, path, headers, body}, from, state) do
    # In both the successful case and the error case, we make sure to update the connection
    # struct in the state since the connection is an immutable data structure.
    case Mint.HTTP.request(state.conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        state = put_in(state.conn, conn)
        # We store the caller this request belongs to and an empty map as the response.
        # The map will be filled with status code, headers, and so on.
        state = put_in(state.requests[request_ref], %{from: from, response: %{}})
        {:noreply, state}

      {:error, conn, reason} ->
        state = put_in(state.conn, conn)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:close, _from, state) do
    {:ok, conn} = result = Mint.HTTP.close(state.conn)
    {:reply, result, put_in(state.conn, conn)}
  end

  @impl true
  def handle_info(message, state) do
    # We should handle the error case here as well, but we're omitting it for brevity.
    case Mint.HTTP.stream(state.conn, message) do
      :unknown ->
        _ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
        {:noreply, state}

      {:ok, conn, responses} ->
        state = put_in(state.conn, conn)
        state = Enum.reduce(responses, state, &process_response/2)
        {:noreply, state}
    end
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status], status)
  end

  defp process_response({:headers, request_ref, headers}, state) do
    state = put_in(state.requests[request_ref].response[:headers], headers)
    put_in(state.encoding, find_content_encoding(headers))
  end

  defp process_response({:data, request_ref, data}, state) do
    data = Enum.reduce(state.encoding, data, &decompress(&1, &2, state.stream))

    update_in(
      state.requests[request_ref].response[:data],
      fn existing_data ->
        (existing_data || []) ++ [data]
      end
    )
  end

  defp decompress(nil, data, _stream), do: data
  defp decompress("identity", data, _stream), do: data
  defp decompress(compression, data, stream) when compression in ["gzip", "deflate", "x-gzip"] do
    {_, decompressed} = :zlib.safeInflate(stream, data)
    decompressed
  end
  defp decompress(_compression, data, _stream), do: data

  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    :zlib.close(state.stream)
    response = %{response | data: Enum.join(response.data, "")}
    GenServer.reply(from, {:ok, response})
    state
  end

  defp find_content_encoding(headers) do
    Enum.find_value(
      headers,
      [],
      fn {name, value} ->
        if String.downcase(name) == "content-encoding" do
          value
          |> String.downcase()
          |> String.replace(~r|\s|, "")
          |> String.split(",")
          |> Enum.reverse()
        end
      end
    )
  end
end
