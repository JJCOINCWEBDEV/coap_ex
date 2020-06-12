defmodule CoAP.Message.Type do
  @type t :: :con | :non | :ack | :reset

  @types %{
    0 => :con,
    1 => :non,
    2 => :ack,
    3 => :reset
  }
  @types_map Enum.into(@types, %{}, fn {k, v} -> {v, k} end)

  # Encode a request type (con/non/ack/reset) for binary message use
  @spec encode(t()) :: integer
  def encode(type) when is_atom(type), do: @types_map[type]

  # Decode a binary message into its request type (con/non/ack/reset)
  @spec decode(integer) :: t()
  def decode(type) when is_integer(type), do: @types[type]
end
