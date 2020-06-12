defmodule CoAP.Message.Options.Decoder do
  def options_and_payload(options) when is_binary(options) do
    {option_list, payload} = decode(options)
    {option_list |> Enum.into(%{}), payload}
  end

  defp decode(options), do: decode(options, 0, [])
  defp decode(<<>>, _last_num, option_list), do: {option_list, <<>>}
  defp decode(<<0xFF, payload::binary>>, _last_num, option_list), do: {option_list, payload}

  defp decode(<<delta::size(4), length::size(4), tail::binary>>, delta_sum, option_list) do
    {key, length, tail} = decode_extended(delta_sum, delta, length, tail)

    # key becomes the next delta_sum
    case tail do
      <<value::binary-size(length), rest::binary>> ->
        decode(rest, key, append_option(CoAP.Message.Option.decode(key, value), option_list))

      <<>> ->
        decode(<<>>, key, append_option(CoAP.Message.Option.decode(key, <<>>), option_list))
    end
  end

  defp decode_extended(delta_sum, delta, length, tail) do
    {tail1, key} =
      cond do
        delta < 13 ->
          {tail, delta_sum + delta}

        delta == 13 ->
          # TODO: size here `::size(4)`?
          <<key, new_tail1::binary>> = tail
          {new_tail1, delta_sum + key + 13}

        delta == 14 ->
          <<key::size(16), new_tail1::binary>> = tail
          {new_tail1, delta_sum + key + 269}
      end

    {tail2, option_length} =
      cond do
        length < 13 ->
          {tail1, length}

        length == 13 ->
          # TODO: size here `::size(4)`?
          <<extended_option_length, new_tail2::binary>> = tail1
          {new_tail2, extended_option_length + 13}

        length == 14 ->
          <<extended_option_length::size(16), new_tail2::binary>> = tail1
          {new_tail2, extended_option_length + 269}
      end

    {key, option_length, tail2}
  end

  # put options of the same id into one list
  # Is this new key already in the list as the previous value?
  defp append_option({key, value}, [{key, values} | options]) do
    case CoAP.Message.Option.repeatable?(key) do
      true ->
        # we must keep the order
        [{key, values ++ [value]} | options]

      false ->
        throw({:error, "#{key} is not repeatable"})
    end
  end

  defp append_option({key, value}, options) do
    case CoAP.Message.Option.repeatable?(key) do
      true -> [{key, [value]} | options]
      false -> [{key, value} | options]
    end
  end
end
