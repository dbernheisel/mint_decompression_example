defmodule MintDecompression.ConnectionProcess do
  use GenServer
  require Logger

  defstruct [:conn, requests: %{}]

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
    with {:ok, conn} <- Mint.HTTP2.connect(scheme, host, port) do
      state = %__MODULE__{conn: conn}
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
    put_in(state.requests[request_ref].response[:headers], headers)
  end

  defp process_response({:data, request_ref, data}, state) do
    update_in(
      state.requests[request_ref].response[:data],
      fn existing_data ->
        (existing_data || "") <> data
      end
    )
  end

  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    GenServer.reply(from, {:ok, response})
    state
  end
end
