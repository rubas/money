defmodule Money.Parser do
  @moduledoc false

  # parsec:Money.Parser
  import NimbleParsec
  import Money.Combinators

  defparsec(:money_parser, choice([money_with_currency(), accounting_format()]))
  # parsec:Money.Parser
end
