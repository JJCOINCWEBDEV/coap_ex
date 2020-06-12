defmodule CoAP.Message do
  defstruct ~w(version type request code method status message_id token options multipart payload raw_size)a

  @type t :: %__MODULE__{
          version: integer,
          type: request_type,
          request: boolean,
          code: __MODULE__.Code.t(),
          method: request_method | {integer, integer},
          status: integer,
          message_id: integer,
          token: binary,
          options: map,
          multipart: CoAP.Multipart.t(),
          payload: binary,
          raw_size: integer
        }

  @type request_method :: __MODULE__.Code.method()
  @type request_type :: __MODULE__.Type.t()

  @doc "Encodes message to binary. See `#{__MODULE__}.Encoder.encode/1` for details"
  def encode(%__MODULE__{} = message), do: __MODULE__.Encoder.encode(message)

  @doc "Decodes message from binary. See `#{__MODULE__}.Decoder.decode/1` for details"
  def decode(binary), do: __MODULE__.Decoder.decode(binary)
end
