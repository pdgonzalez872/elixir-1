defmodule LedgerTest do
  use ExUnit.Case

  # Let's see what this actually does
  # - seems like there is a header
  # - iterates over the entries, adding a description and a parens if positive or negative amount
  # - new line separator
  # - concept of language, currency and date
  #   - euro or dollar sign on the amount
  #   - comma or period in amount
  #   - language only affects the header
  #   - date is also different:
  #     - `-` as separator for US
  #     - `/` as separator for EU
  #     - EU -> month day year
  #     - US -> day month year
  # - there is a concept of truncating the description if greater than a certain size
  #
  # seems like we need to do 2 things:
  # - solve for the header
  # - sort the rows by date
  # - solve for each row
  #
  #

  test "empty ledger" do
    assert Ledger.format_entries(:usd, :en_US, []) ==
             """
             Date       | Description               | Change\s\s\s\s\s\s\s
             """
  end

  test "one entry" do
    entries = [
      %{amount_in_cents: -1000, date: ~D[2015-01-01], description: "Buy present"}
    ]

    assert Ledger.format_entries(:usd, :en_US, entries) ==
             """
             Date       | Description               | Change\s\s\s\s\s\s\s
             01/01/2015 | Buy present               |      ($10.00)
             """
  end

  test "credit and debit" do
    entries = [
      %{amount_in_cents: 1000, date: ~D[2015-01-02], description: "Get present"},
      %{amount_in_cents: -1000, date: ~D[2015-01-01], description: "Buy present"}
    ]

    result = Ledger.format_entries(:usd, :en_US, entries)

    expected =
      """
      Date       | Description               | Change\s\s\s\s\s\s\s
      01/01/2015 | Buy present               |      ($10.00)
      01/02/2015 | Get present               |       $10.00\s
      """

    assert result == expected
  end

  test "multiple entries on same date ordered by description" do
    entries = [
      %{amount_in_cents: 1000, date: ~D[2015-01-01], description: "Get present"},
      %{amount_in_cents: -1000, date: ~D[2015-01-01], description: "Buy present"}
    ]

    assert Ledger.format_entries(:usd, :en_US, entries) ==
             """
             Date       | Description               | Change\s\s\s\s\s\s\s
             01/01/2015 | Buy present               |      ($10.00)
             01/01/2015 | Get present               |       $10.00\s
             """
  end

  test "final order tie breaker is change" do
    entries = [
      %{amount_in_cents: 0, date: ~D[2015-01-01], description: "Something"},
      %{amount_in_cents: -1, date: ~D[2015-01-01], description: "Something"},
      %{amount_in_cents: 1, date: ~D[2015-01-01], description: "Something"}
    ]

    result = Ledger.format_entries(:usd, :en_US, entries)

    expected =
      """
      Date       | Description               | Change\s\s\s\s\s\s\s
      01/01/2015 | Something                 |       ($0.01)
      01/01/2015 | Something                 |        $0.00\s
      01/01/2015 | Something                 |        $0.01\s
      """

    IO.puts(result)
    IO.puts(expected)

    assert result == expected
  end

  test "overlong description is truncated" do
    entries = [
      %{
        amount_in_cents: -123_456,
        date: ~D[2015-01-01],
        description: "Freude schoner Gotterfunken"
      }
    ]

    result = Ledger.format_entries(:usd, :en_US, entries)

    expected =
      """
      Date       | Description               | Change\s\s\s\s\s\s\s
      01/01/2015 | Freude schoner Gotterf... |   ($1,234.56)
      """

    assert result == expected
  end

  test "euros" do
    entries = [
      %{amount_in_cents: -1000, date: ~D[2015-01-01], description: "Buy present"}
    ]

    assert Ledger.format_entries(:eur, :en_US, entries) ==
             """
             Date       | Description               | Change\s\s\s\s\s\s\s
             01/01/2015 | Buy present               |      (€10.00)
             """
  end

  test "Dutch locale" do
    entries = [
      %{amount_in_cents: 123_456, date: ~D[2015-03-12], description: "Buy present"}
    ]

    assert Ledger.format_entries(:usd, :nl_NL, entries) ==
             """
             Datum      | Omschrijving              | Verandering\s\s
             12-03-2015 | Buy present               |   $ 1.234,56\s
             """
  end

  test "Dutch locale and euros" do
    entries = [
      %{amount_in_cents: 123_456, date: ~D[2015-03-12], description: "Buy present"}
    ]

    assert Ledger.format_entries(:eur, :nl_NL, entries) ==
             """
             Datum      | Omschrijving              | Verandering\s\s
             12-03-2015 | Buy present               |   € 1.234,56\s
             """
  end

  test "Dutch negative number with 3 digits before decimal point" do
    entries = [
      %{amount_in_cents: -12345, date: ~D[2015-03-12], description: "Buy present"}
    ]

    assert Ledger.format_entries(:usd, :nl_NL, entries) ==
             """
             Datum      | Omschrijving              | Verandering\s\s
             12-03-2015 | Buy present               |    $ -123,45\s
             """
  end

  test "American negative number with 3 digits before decimal point" do
    entries = [
      %{amount_in_cents: -12345, date: ~D[2015-03-12], description: "Buy present"}
    ]

    assert Ledger.format_entries(:usd, :en_US, entries) ==
             """
             Date       | Description               | Change\s\s\s\s\s\s\s
             03/12/2015 | Buy present               |     ($123.45)
             """
  end
end
