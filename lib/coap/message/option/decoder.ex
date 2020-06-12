defmodule CoAP.Message.Option.Decoder do
  import CoAP.Message.Option, only: [is_unsigned: 1]
  alias CoAP.Message.Decoder.State

  @content_formats %{
    0 => "text/plain",
    40 => "application/link-format",
    41 => "application/xml",
    42 => "application/octet-stream",
    47 => "application/exi",
    50 => "application/json",
    60 => "application/cbor"
  }

  def decode(%State{metadata: %{current_option: option}} = state) do
    key = CoAP.Message.Option.num_to_key(option.num)

    cond do
      key ->
        update_in(state.metadata.current_option, &%{&1 | key: key, value: decode_value(key, option.value)})

      rem(option.num, 2) == 1 ->
        State.add_issue(state, {:error, {:unknown_option, :critical, option.num, option.value}})

      rem(option.num, 2) == 0 ->
        State.add_issue(state, {:warning, {:unknown_option, :elective, option.num, option.value}})
    end
  end

  defp decode_value(:if_none_match, <<>>), do: true
  defp decode_value(:block1, value), do: CoAP.Block.decode(value)
  defp decode_value(:block2, value), do: CoAP.Block.decode(value)

  defp decode_value(:content_format, value) do
    content_id = :binary.decode_unsigned(value)
    @content_formats[content_id] || content_id
  end

  defp decode_value(key, value) when is_unsigned(key), do: :binary.decode_unsigned(value)
  defp decode_value(_key, value), do: value
end
