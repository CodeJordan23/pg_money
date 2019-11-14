defmodule PgMoney.Type do
  @moduledoc """
  Implements how to encode and decode PostgeSQL's `money` data type.
  """

  @behaviour Postgrex.Extension
end
