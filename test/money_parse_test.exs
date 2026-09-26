defmodule MoneyTest.Parse do
  use ExUnit.Case

  describe "Money.parse/2 " do
    test "parses with currency code in front" do
      assert Money.parse("USD 100") == Money.new(:USD, 100)
      assert Money.parse("USD100") == Money.new(:USD, 100)
      assert Money.parse("USD 100 ") == Money.new(:USD, 100)
      assert Money.parse("USD100 ") == Money.new(:USD, 100)
      assert Money.parse("USD 100.00") == Money.new(:USD, "100.00")
    end

    test "parses with a single digit amount" do
      assert Money.parse("USD 1") == Money.new(:USD, 1)
      assert Money.parse("USD1") == Money.new(:USD, 1)
      assert Money.parse("USD9") == Money.new(:USD, 9)
    end

    test "parses with currency code out back" do
      assert Money.parse("100 USD") == Money.new(:USD, 100)
      assert Money.parse("100USD") == Money.new(:USD, 100)
      assert Money.parse("100 USD ") == Money.new(:USD, 100)
      assert Money.parse("100USD ") == Money.new(:USD, 100)
      assert Money.parse("100.00USD") == Money.new(:USD, "100.00")
    end

    @tag :digital_token
    test "parses digital tokens" do
      assert Money.new("BTC", "100") == Money.parse("100 BTC")
      assert Money.new("BTC", "100") == Money.parse("100 Bitcoin")
      assert Money.new("BTC", "100") == Money.parse("BTC 100")
      assert Money.new("BTC", "100") == Money.parse("Bitcoin 100")
    end

    test "parsing with currency strings that are not codes" do
      assert Money.parse("australian dollar 12346.45") == Money.new(:AUD, "12346.45")
      assert Money.parse("12346.45 australian dollars") == Money.new(:AUD, "12346.45")
      assert Money.parse("12346.45 Australian Dollars") == Money.new(:AUD, "12346.45")
      assert Money.parse("12 346 dollar australien", locale: "fr") == Money.new(:AUD, 12_346)
    end

    test "parses with locale specific separators" do
      assert Money.parse("100,00USD", locale: "de") == Money.new(:USD, "100.00")
    end

    test "parses euro (unicode symbol)" do
      assert Money.parse("99.99€") == Money.new(:EUR, "99.99")
    end

    test "currency filtering" do
      assert Money.parse("100 French francs") == Money.new(:FRF, 100)

      assert Money.parse("100 French francs", currency_filter: [:current]) ==
               {:error,
                {Money.UnknownCurrencyError,
                 "The currency \"French francs\" is unknown or not supported"}}
    end

    test "fuzzy matching of currencies" do
      assert Money.parse("100 eurosports", fuzzy: 0.8) == Money.new(:EUR, 100)

      assert Money.parse("100 eurosports", fuzzy: 0.9) ==
               {:error,
                {Money.UnknownCurrencyError,
                 "The currency \"eurosports\" is unknown or not supported"}}
    end

    test "parsing fails if no currency and no default currency" do
      assert Money.parse("100", default_currency: false) ==
               {:error,
                {Money.Invalid,
                 "A currency code, symbol or description must be specified but was not found in \"100\""}}
    end

    test "parse with locale determining currency" do
      assert Money.parse("100", locale: "en") == Money.new(:USD, 100)
      assert Money.parse("100", locale: "de") == Money.new(:EUR, 100)
    end

    test "parse with a default currency" do
      assert Money.parse("100", default_currency: :USD) == Money.new(:USD, 100)
      assert Money.parse("100", default_currency: "USD") == Money.new(:USD, 100)
      assert Money.parse("100", default_currency: "australian dollars") == Money.new(:AUD, 100)
    end

    test "with locale overrides" do
      # A locale that has a regional override. The regional override
      # takes precedence and hence the currency is USD
      assert Money.parse("100", locale: "zh-Hans-u-rg-uszzzz") == Money.new(:USD, 100)

      # A locale that has a regional override and a currency
      # override uses the currency override as precedent over
      # the regional override. In this case, EUR
      assert Money.parse("100", locale: "zh-Hans-u-rg-uszzzz-cu-eur") == Money.new(:EUR, 100)
    end

    test "accounting format negates an already-negative amount" do
      assert Money.parse("($-127.54)", locale: "en") == Money.new(:USD, "127.54")
    end

    test "parse with negative numbers" do
      assert Money.parse("-127,54 €", locale: "fr") == Money.new(:EUR, "-127.54")
      assert Money.parse("-127,54€", locale: "fr") == Money.new(:EUR, "-127.54")

      assert Money.parse("€ 127,54-", locale: "nl") == Money.new(:EUR, "-127.54")
      assert Money.parse("€127,54-", locale: "nl") == Money.new(:EUR, "-127.54")

      assert Money.parse("($127.54)", locale: "en") == Money.new(:USD, "-127.54")

      assert Money.parse("CHF -127.54", locale: "de-CH") == Money.new(:CHF, "-127.54")
      assert Money.parse("-127.54 CHF", locale: "de-CH") == Money.new(:CHF, "-127.54")

      assert Money.parse("kr-127,54", locale: "da") == Money.new(:DKK, "-127.54")
      assert Money.parse("kr -127,54", locale: "da") == Money.new(:DKK, "-127.54")
    end

    test "de locale" do
      assert Money.parse("1.127,54 €", locale: "de") == Money.new(:EUR, "1127.54")
    end

    test "Round trip parsing" do
      assert Money.parse("1 127,54 €", locale: "fr") ==
               Money.new!(:EUR, "1127.54")
               |> Money.to_string!(locale: "fr")
               |> Money.parse(locale: "fr")
    end

    test "parsing strings that have `.` in them" do
      assert Money.parse("4.200,00 kr.", locale: "da") == Money.new(:DKK, "4200.00")
    end

    test "parse a string that has RTL markers" do
      assert Money.parse("\u200F1.234,56\u00A0د.م.\u200F", locale: "ar-MA") ==
               Money.new(:MAD, "1234.56")
    end

    test "Parse a money string that uses a non-breaking-space for a separator" do
      assert Money.parse("US$30\u00A0000,00", locale: :en_ZA, separators: :standard) ==
               Money.new(:USD, "30000.00")
    end
  end

  describe "Money.parse/2 reads what Money.to_string/2 formats" do
    @formatted [
      {"de-CH", :CHF, "1234.56", :currency, "CHF\u00A01'234.56"},
      {"de-CH", :CHF, "1234.56", :accounting, "CHF\u00A01'234.56"},
      {"de-CH", :CHF, "-1234.56", :currency, "CHF-1'234.56"},
      {"de-CH", :CHF, "-1234.56", :accounting, "CHF-1'234.56"},
      {"fr-CH", :CHF, "1234.56", :currency, "1'234.56\u00A0CHF"},
      {"fr-CH", :CHF, "1234.56", :accounting, "1'234.56\u00A0CHF"},
      {"fr-CH", :CHF, "-1234.56", :currency, "-1'234.56\u00A0CHF"},
      {"fr-CH", :CHF, "-1234.56", :accounting, "(1'234.56\u00A0CHF)"},
      {"de-AT", :EUR, "1234.56", :currency, "\u20AC\u00A01.234,56"},
      {"de-AT", :EUR, "1234.56", :accounting, "\u20AC\u00A01.234,56"},
      {"de-AT", :EUR, "-1234.56", :currency, "-\u20AC\u00A01.234,56"},
      {"de-AT", :EUR, "-1234.56", :accounting, "-\u20AC\u00A01.234,56"},
      {"en", :USD, "1234.56", :currency, "$1,234.56"},
      {"en", :USD, "1234.56", :accounting, "$1,234.56"},
      {"en", :USD, "-1234.56", :currency, "-$1,234.56"},
      {"en", :USD, "-1234.56", :accounting, "($1,234.56)"},
      {"sv", :SEK, "1234.56", :currency, "1\u00A0234,56\u00A0kr"},
      {"sv", :SEK, "1234.56", :accounting, "1\u00A0234,56\u00A0kr"},
      {"sv", :SEK, "-1234.56", :currency, "\u22121\u00A0234,56\u00A0kr"},
      {"sv", :SEK, "-1234.56", :accounting, "\u22121\u00A0234,56\u00A0kr"},
      {"ar", :EGP, "1234.56", :currency, "\u200F1,234.56\u00A0\u062C.\u0645.\u200F"},
      {"ar", :EGP, "1234.56", :accounting, "\u061C1,234.56\u00A0\u062C.\u0645.\u200F"},
      {"ar", :EGP, "-1234.56", :currency, "\u200F\u200E-1,234.56\u00A0\u062C.\u0645.\u200F"},
      {"ar", :EGP, "-1234.56", :accounting, "(\u061C1,234.56\u00A0\u062C.\u0645.\u200F)"},
      {"ar-EG", :EGP, "-1234.56", :currency,
       "\u061C-\u200F\u0661\u066C\u0662\u0663\u0664\u066B\u0665\u0666\u00A0\u062C.\u0645.\u200F"}
    ]

    for {locale, currency, amount, format, string} <- @formatted do
      test "#{locale} #{currency} #{amount} as #{format} formats as #{inspect(string)} and parses back" do
        money = Money.new!(unquote(currency), unquote(amount))
        options = [locale: unquote(locale)]

        assert Money.to_string(money, [format: unquote(format)] ++ options) ==
                 {:ok, unquote(string)}

        assert Money.parse(unquote(string), options) == money
      end
    end

    test "de-AT reads \u20AC 1.234 as 1234 euros, grouped as to_string/2 groups euros" do
      assert Money.parse("\u20AC 1.234", locale: "de-AT") == Money.new(:EUR, "1234")
    end

    test "a sign before the currency and one on the amount is an error" do
      assert Money.parse("-CHF -1,234.56", locale: "en") ==
               {:error, {Money.Invalid, "Unable to create money from :CHF and \"--1,234.56\""}}
    end

    test "parentheses negate a Unicode minus amount" do
      assert Money.parse("(\u22125 USD)", locale: "en") == Money.new(:USD, "5")
    end

    test "parses .5 USD as 0.5 and USD 0. as 0" do
      assert Money.parse(".5 USD", locale: "en") == Money.new(:USD, "0.5")
      assert Money.parse("USD 0.", locale: "en") == Money.new(:USD, "0")
    end

    @tag :digital_token
    test "ETH 1.23 formats as ETH1.23 in de and parses back as 1.23" do
      money = Money.new!("ETH", Decimal.new("1.23"))

      assert Money.to_string(money, locale: "de") == {:ok, "ETH1.23"}
      assert Money.parse("ETH1.23", locale: "de") == money
    end

    test "Corsican accounting puts the currency after the parentheses" do
      assert Money.parse("(1\u00A0234,56)\u00A0EUR", locale: "co") == Money.new(:EUR, "-1234.56")
    end
  end

  describe "Money.parse/2 reads a whole price with a dash for the fraction" do
    for locale <- ["de-CH", "fr-CH", "it-CH"],
        {string, amount} <- [
          {"CHF 5.-", "5"},
          {"CHF 5.\u2013", "5"},
          {"5.\u2013 CHF", "5"},
          {"Fr. 5.-", "5"},
          {"Fr. 5.--", "5"},
          {"CHF 1'234.\u2013", "1234"},
          {"CHF -5.-", "-5"},
          {"(CHF 5.-)", "-5"}
        ] do
      test "#{locale} reads #{inspect(string)} as CHF #{amount}" do
        assert Money.parse(unquote(string), locale: unquote(locale)) ==
                 Money.new(:CHF, unquote(amount))
      end
    end

    test "nl reads \u20AC 5,- as 5 euros and \u20AC 5,00- as -5 euros" do
      assert Money.parse("\u20AC 5,-", locale: "nl") == Money.new(:EUR, "5")
      assert Money.parse("\u20AC 5,00-", locale: "nl") == Money.new(:EUR, "-5.00")
    end

    test "de-CH reads CHF 5.00- as -5 francs" do
      assert Money.parse("CHF 5.00-", locale: "de-CH") == Money.new(:CHF, "-5.00")
    end

    test "de groups with a dot, so CHF 5.- is an error, not 5 or -5 francs" do
      assert Money.parse("CHF 5.-", locale: "de") ==
               {:error, {Money.Invalid, "Unable to create money from :CHF and \"5.\""}}
    end

    test "Fr. is the franc only where the franc is the currency of the locale" do
      assert Money.parse("Fr. 5.-", locale: "de") ==
               {:error,
                {Money.UnknownCurrencyError, "The currency \"Fr.\" is unknown or not supported"}}
    end
  end
end
