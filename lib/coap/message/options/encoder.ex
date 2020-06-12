defmodule CoAP.Message.Options.Encoder do
  def encode(options) when is_map(options) do
    options
    |> Map.to_list()
    |> Enum.map(&CoAP.Message.Option.encode/1)
    |> List.flatten()
    |> sort
    |> encode(0, <<>>)
  end

  # Take key/value pairs from options and turn them into option_id/binary values list
  # defp encode_options([], acc), do: acc
  # defp encode_options([{_key, nil} | options], acc), do: encode_options(options, acc)
  # defp encode_options([{key, value} | options], acc) do
  #   encode_options(options, [({key, value}) | acc])
  # end

  defp sort(options), do: :lists.keysort(1, options)

  # defp encode_option_list(options, nil), do: encode_option_list(options)
  # defp encode_option_list(options, <<>>), do: encode_option_list(options)
  # defp encode_option_list(options, payload) do
  #   <<encode_option_list(options)::binary, 0xFF, payload::binary>>
  # end

  defp encode([{key, value} | option_list], delta_sum, acc) do
    {delta, extended_number} =
      cond do
        key - delta_sum >= 269 ->
          {14, <<key - delta_sum - 269::size(16)>>}

        key - delta_sum >= 13 ->
          {13, <<key - delta_sum - 13>>}

        true ->
          {key - delta_sum, <<>>}
      end

    {length, extended_length} =
      cond do
        byte_size(value) >= 269 ->
          {14, <<byte_size(value) - 269::size(16)>>}

        byte_size(value) >= 13 ->
          {13, <<byte_size(value) - 13>>}

        true ->
          {byte_size(value), <<>>}
      end

    acc2 = <<
      acc::binary,
      delta::size(4),
      length::size(4),
      # TODO: what size should this be?
      extended_number::binary,
      extended_length::binary,
      value::binary
    >>

    encode(option_list, key, acc2)
  end

  defp encode([], _delta_sum, acc), do: acc
end
