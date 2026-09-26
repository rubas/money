defmodule Money.Combinators do
  @moduledoc false

  # The shape of a money string: where the currency, the sign and the
  # accounting parentheses sit around the amount. Localize reads the
  # amount itself, with the separators of the locale.

  import NimbleParsec

  # Unicode :Zs plus tab.
  @whitespace [?\s, ?\t, 0x00A0, 0x1680, 0x2000..0x200A, 0x202F, 0x205F, 0x3000]
  def whitespace do
    repeat(empty(), utf8_char(@whitespace))
    |> label("whitespace")
  end

  # The digits of every number system Localize reads. Han digits are not
  # decimal digits in Unicode, and they appear in currency names, as the
  # 三 in 莫三比克梅蒂卡爾.
  @digits for {_system, %{digits: <<zero::utf8, _rest::binary>> = digits}} <-
                Localize.Number.System.numeric_systems(),
              String.match?(digits, ~r/^\p{Nd}+$/u),
              uniq: true,
              do: zero..(zero + 9)

  @minus [?-, ?−]
  @parens [?(, ?)]

  # A decimal mark can open or close an amount, as in ".5" and "0.".
  @decimal_marks [?., ?,]

  defp digits do
    times(utf8_char(@digits), min: 1)
  end

  def sign do
    utf8_char(@minus)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:sign)
  end

  # From the first digit to the last, with its sign in front.
  def amount do
    optional(utf8_char(@minus) |> ignore(whitespace()))
    |> optional(utf8_char(@decimal_marks))
    |> concat(digits())
    |> repeat(repeat(utf8_char(Enum.map(@digits ++ @parens, &{:not, &1}))) |> concat(digits()))
    |> optional(utf8_char(@decimal_marks))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:amount)
    |> optional(sign())
    |> label("amount")
  end

  def currency do
    utf8_char(Enum.map(@digits ++ @parens ++ @minus, &{:not, &1}))
    |> times(min: 1)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:currency)
    |> label("currency code, symbol or name")
  end

  # The currency before the amount, or after it. A sign before the
  # currency, as in "-€ 1.234,56", belongs to the amount.
  defp money do
    choice([
      amount()
      |> ignore(whitespace())
      |> optional(currency()),
      optional(sign())
      |> concat(currency())
      |> ignore(whitespace())
      |> concat(amount())
    ])
  end

  def money_with_currency do
    money()
    |> eos()
    |> label("money with currency")
  end

  # The currency inside the parentheses, or after them, as in Corsican
  # "(1 234,56) EUR".
  def accounting_format do
    choice([
      parenthesized(money()) |> eos(),
      parenthesized(amount()) |> ignore(whitespace()) |> concat(currency()) |> eos()
    ])
    |> tag(:accounting)
    |> label("money with currency in accounting format")
  end

  defp parenthesized(combinator) do
    ignore(utf8_char([?(]))
    |> ignore(whitespace())
    |> concat(combinator)
    |> ignore(whitespace())
    |> ignore(utf8_char([?)]))
  end
end
