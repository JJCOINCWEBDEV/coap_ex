defmodule CoAP.Message.Options.Decoder do
  alias CoAP.Message.Decoder.State

  defmodule OptionData do
    defstruct ~w(raw_delta raw_length delta length num key value)a
  end

  @spec decode(State.t()) :: State.t()
  def decode(%State{} = state) do
    metadata = state.metadata |> Map.put(:last_option, %OptionData{num: 0}) |> Map.put(:current_option, %OptionData{})

    do_decode(%{state | metadata: metadata})
    |> finish_decode()
  end

  defp do_decode(%State{data: <<>>} = state) do
    state
  end

  defp do_decode(%State{data: <<0xFF, _payload::binary>>} = state) do
    state
  end

  defp do_decode(%State{data: <<raw_delta::size(4), raw_length::size(4), rest::binary>>} = state) do
    put_in(state.metadata.current_option, %OptionData{raw_delta: raw_delta, raw_length: raw_length})
    |> State.next(rest, state.message)
    |> State.run(&decode_extended_field(&1, :raw_delta, :delta))
    |> State.run(&decode_extended_field(&1, :raw_length, :length))
    |> State.run(&calculate_num/1)
    |> State.run(&decode_key_value/1)
    |> State.run(&into_message_options/1)
    |> State.run(&do_decode/1)
  end

  defp finish_decode(state) do
    message = %{state.message | multipart: CoAP.Multipart.build(state.message)}
    metadata = state.metadata |> Map.delete(:last_option) |> Map.delete(:current_option)
    State.step(state, state.flow_control, state.data, message, metadata)
  end

  defp decode_extended_field(%State{} = state, field, extended_field) do
    decode_extended_field(state, field, extended_field, Map.fetch!(state.metadata.current_option, field))
  end

  defp decode_extended_field(
         %State{data: <<extended_value::size(8), rest::bitstring>>} = state,
         _field,
         extended_field,
         13
       ) do
    update_in(
      state.metadata.current_option,
      &%{&1 | extended_field => extended_value + 13}
    )
    |> State.next(rest, state.message)
  end

  defp decode_extended_field(
         %State{data: <<extended_value::size(16), rest::bitstring>>} = state,
         _field,
         extended_field,
         14
       ) do
    update_in(
      state.metadata.current_option,
      &%{&1 | extended_field => extended_value + 269}
    )
    |> State.next(rest, state.message)
  end

  defp decode_extended_field(%State{} = state, _field, extended_field, 15) do
    state
    |> State.add_issue({:error, {:option_payload_marker_conflict, extended_field}})
    |> State.stop(state.data, state.message)
  end

  defp decode_extended_field(%State{} = state, _field, extended_field, value) do
    update_in(state.metadata.current_option, &%{&1 | extended_field => value})
    |> State.next(state.data, state.message)
  end

  defp calculate_num(%State{} = state) do
    update_in(state.metadata.current_option, &%{&1 | num: state.metadata.last_option.num + &1.delta})
  end

  defp decode_key_value(%State{metadata: %{current_option: %{length: length}}} = state) do
    case state.data do
      <<value::binary-size(length), rest::bitstring>> ->
        update_in(state.metadata.current_option, &%{&1 | value: value})
        |> State.next(rest, state.message)
        |> CoAP.Message.Option.decode()

      _else ->
        state
        |> State.add_issue({:error, {:message_incomplete, :option, state.data}})
        |> State.stop(state.data, state.message)
    end
  end

  defp into_message_options(%State{metadata: %{current_option: %{key: key} = option}} = state) when not is_nil(key) do
    into_message_options(state, CoAP.Message.Option.repeatable?(option.key))
  end

  defp into_message_options(%State{metadata: %{current_option: %{key: key}}} = state) when is_nil(key) do
    State.next(state, state.data, state.message)
  end

  defp into_message_options(%State{metadata: %{current_option: option, last_option: last_option}} = state, true) do
    new_metadata =
      state.metadata |> Map.put(:last_option, state.metadata.current_option) |> Map.put(:current_option, nil)

    options =
      if last_option.num == option.num do
        Map.update!(state.message.options || %{}, option.key, &(&1 ++ [option.value]))
      else
        Map.put_new(state.message.options || %{}, option.key, [option.value])
      end

    State.next(state, state.data, %{state.message | options: options}, new_metadata)
  end

  defp into_message_options(%State{metadata: %{current_option: option, last_option: last_option}} = state, false) do
    new_metadata =
      state.metadata |> Map.put(:last_option, state.metadata.current_option) |> Map.put(:current_option, nil)

    if last_option.num == option.num do
      state
      |> State.add_issue({:error, {:supernumary_option, option.key, option.value}})
      |> State.next(state.data, state.message, new_metadata)
    else
      options = Map.put_new(state.message.options || %{}, option.key, option.value)
      State.next(state, state.data, %{state.message | options: options}, new_metadata)
    end
  end
end
