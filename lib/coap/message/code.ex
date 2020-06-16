defmodule CoAP.Message.Code do
  alias CoAP.Message.Decoder.State

  @typedoc "Tuple of two codes - first one is class code, second one is detail code"
  @type t :: {integer(), integer()}

  @type method :: :get | :post | :put | :delete
  @type status ::
          {:ok, :created | :deleted | :valid | :changed | :content | :continue}
          | {:error,
             :bad_request
             | :unauthorized
             | :bad_option
             | :forbidden
             | :not_found
             | :method_not_allowed
             | :not_acceptable
             | :request_entity_incomplete
             | :precondition_failed
             | :request_entity_too_large
             | :unsupported_content_format
             | :internal_server_error
             | :not_implemented
             | :bad_gateway
             | :service_unavailable
             | :gateway_timeout
             | :proxying_not_supported}

  @type request_response :: {:request, method | nil} | {:response, status | nil} | :empty

  @request_codes %{
    # RFC 7252
    # atom indicate a request
    {0, 01} => :get,
    {0, 02} => :post,
    {0, 03} => :put,
    {0, 04} => :delete
  }
  @request_codes_map Enum.into(@request_codes, %{}, fn {k, v} -> {v, k} end)

  @response_codes %{
    # success is a tuple {ok, ...}
    {2, 01} => {:ok, :created},
    {2, 02} => {:ok, :deleted},
    {2, 03} => {:ok, :valid},
    {2, 04} => {:ok, :changed},
    {2, 05} => {:ok, :content},
    # block
    {2, 31} => {:ok, :continue},
    # error is a tuple {error, ...}
    {4, 00} => {:error, :bad_request},
    {4, 01} => {:error, :unauthorized},
    {4, 02} => {:error, :bad_option},
    {4, 03} => {:error, :forbidden},
    {4, 04} => {:error, :not_found},
    {4, 05} => {:error, :method_not_allowed},
    {4, 06} => {:error, :not_acceptable},
    # block
    {4, 08} => {:error, :request_entity_incomplete},
    {4, 12} => {:error, :precondition_failed},
    {4, 13} => {:error, :request_entity_too_large},
    {4, 15} => {:error, :unsupported_content_format},
    {5, 00} => {:error, :internal_server_error},
    {5, 01} => {:error, :not_implemented},
    {5, 02} => {:error, :bad_gateway},
    {5, 03} => {:error, :service_unavailable},
    {5, 04} => {:error, :gateway_timeout},
    {5, 05} => {:error, :proxying_not_supported}
  }
  @response_codes_map Enum.into(@response_codes, %{}, fn {k, v} -> {v, k} end)

  defguard is_code(code)
           when is_tuple(code) and tuple_size(code) == 2 and is_integer(elem(code, 0)) and is_integer(elem(code, 1))

  defguard is_empty(code) when elem(code, 0) == 0 and elem(code, 1) == 0

  defguard is_request(code) when elem(code, 0) == 0

  defguard is_valid_code(code)
           when is_code(code) and elem(code, 0) in [0, 2, 3, 4, 5] and elem(code, 1) >= 0 and elem(code, 1) <= 31

  def decode(code, state) when is_code(code) and is_valid_code(code) and is_empty(code) do
    State.next(state, state.data, %{state.message | request_response: :empty})
  end

  def decode(code, state) when is_code(code) and is_valid_code(code) and is_request(code) do
    case Map.fetch(@request_codes, code) do
      {:ok, value} ->
        State.next(state, state.data, %{state.message | request_response: {:request, value}})

      :error ->
        state
        |> State.add_issue({:warning, {:unknown_request_method, code}})
        |> State.next(state.data, %{state.message | request_response: {:request, nil}})
    end
  end

  def decode(code, state) when is_code(code) and is_valid_code(code) and not is_request(code) do
    case Map.fetch(@response_codes, code) do
      {:ok, value} ->
        State.next(state, state.data, %{state.message | request_response: {:response, value}})

      :error ->
        state
        |> State.add_issue({:warning, {:unknown_response_status, code}})
        |> State.next(state.data, %{state.message | request_response: {:response, nil}})
    end
  end

  def decode(code, state) when is_code(code) and not is_valid_code(code) do
    request_response = if request?(code), do: {:request, nil}, else: {:response, nil}

    state
    |> State.add_issue({:error, {:reserved_code_used, code}})
    |> State.next(state.data, %{state.message | request_response: request_response})
  end

  @spec request?(t()) :: boolean
  def request?(code) when is_code(code) and is_request(code), do: true
  def request?(_), do: false

  @doc """
  Encode the request method (get/post/put/delete) for binary message use

  Examples

      iex> CoAP.Message.Code.encode_request(:get)
      {0, 01}

      iex> CoAP.Message.Code.encode_request(:post)
      {0, 02}

  """
  @spec encode_request(method()) :: t()
  def encode_request(method), do: @request_codes_map[method]

  @doc """
  Encode the response code for binary message use

  Examples

      iex> CoAP.Message.Code.encode_response({:ok, :created})
      {2, 01}

      iex> CoAP.Message.Code.encode_response({:ok, :continue})
      {2, 31}

  """
  @spec encode_response(status()) :: t()
  def encode_response(status), do: @response_codes_map[status]
end
