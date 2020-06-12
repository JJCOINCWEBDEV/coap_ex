defmodule CoAP.Message.Decoder do
  import CoAP.Message.Code, only: [is_valid_code: 1]

  @type decode_warning_reason ::
          {:unknown_request_method, CoAP.Message.Code.t()}
          | {:unknown_response_status, CoAP.Message.Code.t()}
          | {:unknown_option, :elective, integer, binary}
  @type decode_ignore_reason :: {:unknown_version, integer}
  @type decode_error_reason ::
          {:message_incomplete, atom, binary}
          | {:token_length_too_large, integer}
          | {:reserved_code_used, CoAP.Message.Code.t()}
          | {:unknown_option, :critical, integer, binary}
          | {:supernumary_option, atom, binary}
          | :malformed_payload_marker
          | {:option_payload_marker_conflict, :delta | :length}

  defmodule State do
    defstruct [:data, :message, :metadata, :flow_control, :issues]

    @type t :: %__MODULE__{
            # raw bitstring part yet to be parsed
            data: bitstring,
            # resulting coap message
            message: %CoAP.Message{},
            # metadata about message that only decoder needs, like token_length
            metadata: Map.t(),
            # :next to continue decoding, :stop to force decoding to end and return current results
            flow_control: :next | :stop,
            # issues accumulated during decoding
            issues: [decoder_issue]
          }

    @type decoder_issue ::
            {:warning, CoAP.Message.Decoder.decode_warning_reason()}
            | {:ignore, CoAP.Message.Decoder.decode_ignore_reason()}
            | {:error, CoAP.Message.Decoder.decode_error_reason()}

    @spec init(bitstring) :: t()
    def init(data) do
      %__MODULE__{
        data: data,
        message: %CoAP.Message{raw_size: byte_size(data)},
        metadata: %{},
        flow_control: :next,
        issues: []
      }
    end

    @spec run(t(), (t() -> t())) :: t()
    def run(%__MODULE__{flow_control: :next} = state, func), do: func.(state)
    def run(%__MODULE__{flow_control: :stop} = state, _func), do: state

    @spec add_issue(t(), decoder_issue) :: t()
    def add_issue(%__MODULE__{} = state, issue), do: %{state | issues: [issue | state.issues]}

    @spec add_issues(t(), [decoder_issue]) :: t()
    def add_issues(%__MODULE__{} = state, issues), do: %{state | issues: issues ++ state.issues}

    @spec next(t(), bitstring, %CoAP.Message{}, Map.t() | nil) :: t()
    def next(%__MODULE__{} = state, data, message, metadata \\ nil) do
      step(state, :next, data, message, metadata)
    end

    @spec stop(t(), bitstring, %CoAP.Message{}, Map.t() | nil) :: t()
    def stop(%__MODULE__{} = state, data, message, metadata \\ nil) do
      step(state, :stop, data, message, metadata)
    end

    @spec step(t(), :next | :stop, bitstring, %CoAP.Message{}, Map.t() | nil) :: t()
    def step(%__MODULE__{} = state, flow_control, data, message, metadata \\ nil) do
      metadata = metadata || state.metadata
      %{state | data: data, message: message, flow_control: flow_control, metadata: metadata}
    end

    def result(%__MODULE__{message: message, issues: issues}) do
      cond do
        Enum.any?(issues, fn {type, _issue} -> type == :ignore end) ->
          ignore_issues =
            issues
            |> Enum.filter(fn {type, _issue} -> type == :ignore end)
            |> Enum.reduce([], fn {_type, issue}, acc -> [issue | acc] end)

          {:ignore, message, ignore_issues}

        Enum.any?(issues, fn {type, _issue} -> type == :error end) ->
          ignore_issues =
            issues
            |> Enum.filter(fn {type, _issue} -> type == :error end)
            |> Enum.reduce([], fn {_type, issue}, acc -> [issue | acc] end)

          {:error, message, ignore_issues}

        Enum.any?(issues, fn {type, _issue} -> type == :warning end) ->
          ignore_issues =
            issues
            |> Enum.filter(fn {type, _issue} -> type == :warning end)
            |> Enum.reduce([], fn {_type, issue}, acc -> [issue | acc] end)

          {:warning, message, ignore_issues}

        Enum.count(issues) == 0 ->
          {:ok, message}
      end
    end
  end

  @doc """
  Decode binary coap message into a struct.

  Will return one of:
  * `{:ok, CoAP.Message.t()}` if there were no issues with decoding this message
  * `{:warning, %CoAP.Message{}, [decode_warning_reason]}` if decoder encountered some irregularities, but was able to decode the message. Message can be safely processed by handler. See type `decode_warning_reason` for a list of possible reasons.
  * `{:ignore, %CoAP.Message{}, [decode_ignore_reason]}` if decoder encountered some unrecoverable protocol irregularity. Message must be ignored by handler according to spec. See type `decode_ignore_reason` for a list of possible reasons.
  * `{:error, %CoAP.Message{}, [decode_error_reason]} if decoder encountered protocol violations. Message should trigger some sort of error response by implementation. See type `decode_error_reason` for a list of possible reasons.

  What decoder returns is defined using following priority:
  * :ignore is returned if there were no critical error's
  * :error is returned if there were no critical errors and no ignores
  * :warning is returned if there were no critical errors, no ignores and no errors
  * :ok is returned if there were no critical errors, no ignores, no errors and no warnings

  Examples:

      iex> message = <<0x44, 0x01, 0x00, 0x01, 0xa3, 0xf9, 0x6b, 0x81, 0x39, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x68, 0x6f, 0x73, 0x74, 0x83, 0x61, 0x70, 0x69, 0x00, 0x11, 0x00, 0x39, 0x77, 0x68, 0x6f, 0x3d, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0xff, 0x64, 0x61, 0x74, 0x61>>
      iex> CoAP.Message.decode(message)
      {:ok, %CoAP.Message{
        version: 1,
        type: :con,
        request: true,
        code: {0, 1},
        message_id: 1,
        token: <<163, 249, 107, 129>>,
        options: %{
           uri_path: ["api", ""],
           uri_query: ["who=world"],
           content_format: "text/plain",
           uri_host: "localhost"
        },
        payload: "data",
        multipart: %CoAP.Multipart{control: nil, description: nil, more: false, multipart: false, number: 0},
        method: :get,
        raw_size: 40
      }}

      iex> data = <<0x40, 0x01, 0x21, 0x27, 0xB3, 0x61, 0x70, 0x69, 0xC1, 0x15, 0xFF, 0x32, 0x24, 0x0A, 0x0C, 0x0A, 0x0A, 0x33, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x31, 0x36, 0x34, 0x12, 0x14, 0x30, 0x31, 0x30, 0x39, 0x32, 0x34, 0x35, 0x30, 0x46, 0x30, 0x41, 0x46, 0x6D, 0x63, 0x75, 0x2D, 0x65, 0x76, 0x74, 0x32>>
      iex> {:ok, message} = CoAP.Message.decode(data)
      iex> message.multipart
      %CoAP.Multipart{
        description: nil,
        control: %CoAP.Block{more: false, number: 1, size: 512},
        multipart: true,
        requested_number: 1,
        requested_size: 512
      }

      iex> message = <<0x80, 0x00, 0x00, 0x01>>
      iex> CoAP.Message.decode(message)
      {:ignore, %CoAP.Message{raw_size: 4}, [{:unknown_version, 2}]}

      iex> message = <<0x45, 0x00, 0x00, 0x01, 0xAA, 0xAA, 0xAA>>
      iex> CoAP.Message.decode(message)
      {:error, %CoAP.Message{raw_size: 7, version: 1, type: :con, code: {0, 0}, message_id: 1, request: true}, [{:message_incomplete, :token, <<0xAA, 0xAA, 0xAA>>}]}
  """
  @spec decode(binary) ::
          {:ok, CoAP.Message.t()}
          | {:warning, %CoAP.Message{}, [decode_warning_reason]}
          | {:ignore, %CoAP.Message{}, [decode_ignore_reason]}
          | {:error, %CoAP.Message{}, [decode_error_reason]}
  def decode(raw_data) do
    State.init(raw_data)
    |> State.run(&decode_field(&1, :version))
    |> State.run(&decode_field(&1, :type))
    |> State.run(&decode_field(&1, :token_length))
    |> State.run(&decode_field(&1, :code))
    |> State.run(&decode_field(&1, :message_id))
    |> State.run(&decode_field(&1, :token))
    |> State.run(&decode_field(&1, :options))
    |> State.run(&decode_field(&1, :payload))
    |> State.result()
  end

  @spec decode_field(State.t(), atom) :: State.t()

  defp decode_field(%State{data: <<1::unsigned-integer-size(2), rest::bitstring>>} = state, :version) do
    State.next(state, rest, %{state.message | version: 1})
  end

  defp decode_field(%State{data: <<other::unsigned-integer-size(2), rest::bitstring>>} = state, :version) do
    state
    |> State.add_issue({:ignore, {:unknown_version, other}})
    |> State.stop(rest, state.message)
  end

  defp decode_field(%State{data: <<type::unsigned-integer-size(2), rest::bitstring>>} = state, :type) do
    State.next(state, rest, %{state.message | type: CoAP.Message.Type.decode(type)})
  end

  defp decode_field(%State{data: <<token_length::unsigned-integer-size(4), rest::bitstring>>} = state, :token_length)
       when token_length <= 8 do
    State.next(state, rest, state.message, Map.put(state.metadata, :token_length, token_length))
  end

  defp decode_field(%State{data: <<token_length::unsigned-integer-size(4), rest::bitstring>>} = state, :token_length)
       when token_length > 8 do
    state
    |> State.add_issue({:error, {:token_length_too_large, token_length}})
    |> State.stop(rest, state.message)
  end

  defp decode_field(
         %State{
           data: <<code_class::unsigned-integer-size(3), code_detail::unsigned-integer-size(5), rest::bitstring>>
         } = state,
         :code
       )
       when is_valid_code({code_class, code_detail}) do
    code = {code_class, code_detail}
    message = %{state.message | code: code, request: CoAP.Message.Code.request?(code)}
    issues = state.issues

    {message, issues} =
      case CoAP.Message.Code.decode_request(code) do
        {:ok, method} -> {%{message | method: method}, issues}
        :error -> {message, [{:warning, {:unknown_request_method, code}} | issues]}
      end

    {message, issues} =
      case CoAP.Message.Code.decode_response(code) do
        {:ok, status} -> {%{message | status: status}, issues}
        :error -> {message, [{:warning, {:unknown_response_status, code}} | issues]}
      end

    state
    |> State.add_issues(issues)
    |> State.next(rest, message)
  end

  defp decode_field(
         %State{
           data: <<code_class::unsigned-integer-size(3), code_detail::unsigned-integer-size(5), rest::bitstring>>
         } = state,
         :code
       )
       when not is_valid_code({code_class, code_detail}) do
    code = {code_class, code_detail}
    message = %{state.message | code: code, request: CoAP.Message.Code.request?(code)}

    state
    |> State.add_issue({:error, {:reserved_code_used, code}})
    |> State.next(rest, message)
  end

  defp decode_field(%State{data: <<message_id::unsigned-integer-size(16), rest::bitstring>>} = state, :message_id) do
    State.next(state, rest, %{state.message | message_id: message_id})
  end

  defp decode_field(%State{metadata: %{token_length: token_length}} = state, :token) do
    case state.data do
      <<token::binary-size(token_length), rest::bitstring>> ->
        State.next(state, rest, %{state.message | token: token})

      _else ->
        state
        |> State.add_issue({:error, {:message_incomplete, :token, state.data}})
        |> State.stop(state.data, state.message)
    end
  end

  defp decode_field(%State{} = state, :options) do
    CoAP.Message.Options.decode(state)
  end

  defp decode_field(%State{data: payload} = state, :payload) when byte_size(payload) == 0 do
    State.next(state, <<>>, %{state.message | payload: payload})
  end

  defp decode_field(%State{data: <<0xFF, payload::binary>>} = state, :payload) when byte_size(payload) > 0 do
    State.next(state, <<>>, %{state.message | payload: payload})
  end

  defp decode_field(%State{data: <<0xFF>>} = state, :payload) do
    state
    |> State.add_issue({:error, :malformed_payload_marker})
    |> State.stop(<<0xFF>>, state.message)
  end

  defp decode_field(%State{} = state, field) do
    state
    |> State.add_issue({:error, {:message_incomplete, field, state.data}})
    |> State.stop(state.data, state.message)
  end
end
