defmodule Ledger do
  @doc """
  Format the given entries given a currency and locale
  """

  defmodule LineItem do
    @moduledoc """
    Data structure that holds the info we need
    """

    defstruct [
      :date,
      :amount_in_cents,
      :description,
      :locale,
      :currency,
      :currency_symbol,
      :currency_separator,
      :currency_separator_cents,
      :pretty,
      :pretty_date,
      :pretty_amount,
      :pretty_description
    ]

    def new(args) do
      struct!(__MODULE__, args)
    end
  end

  def format_entries(_, locale, []) do
    header(locale)
  end

  def format_entries(currency, locale, entries) do
    header = header(locale)

    line_items =
      entries
      |> Enum.map(fn e ->
        currency_symbol =
          case currency do
            :usd -> "$"
            :eur -> "€"
          end

        {currency_separator, currency_separator_cents} =
          case locale do
            :en_US -> {",", "."}
            :nl_NL -> {".", ","}
          end

        e
        |> Map.put(:locale, locale)
        |> Map.put(:currency, currency)
        |> Map.put(:currency_symbol, currency_symbol)
        |> Map.put(:currency_separator, currency_separator)
        |> Map.put(:currency_separator_cents, currency_separator_cents)
        |> LineItem.new()
        |> handle_pretty_amount()
        |> handle_pretty_date()
        |> handle_pretty_description()
        |> handle_pretty()
      end)
      |> sort_line_items()
      |> Enum.map(fn li -> li.pretty end)
      |> Enum.join("\n")
      |> String.trim(" \n")

    header <> line_items <> "\n"
  end

  defp header(:en_US) do
    "Date       | Description               | Change       \n"
  end

  defp header(:nl_NL) do
    "Datum      | Omschrijving              | Verandering  \n"
  end

  defp handle_pretty_amount(%LineItem{} = li) do
    amount = String.split("#{li.amount_in_cents}", "", trim: true)

    pretty_amount =
      case amount do
        [cent] ->
          format_pretty_amount(li, "0#{li.currency_separator_cents}0#{cent}")

        ["-", cent] ->
          format_pretty_amount(li, "0#{li.currency_separator_cents}0#{cent}")

        _other ->
          cents = Enum.take(amount, -2)

          target =
            case amount do
              ["-" = sign | _] -> (amount -- [sign]) -- cents
              _ -> amount -- cents
            end

          pretty_amount =
            target
            |> Enum.reverse()
            |> Enum.chunk_every(3)
            |> Enum.map(fn threes -> Enum.join(threes, "") end)
            |> Enum.intersperse(li.currency_separator)
            |> Enum.join("")
            |> String.reverse()

          format_pretty_amount(
            li,
            "#{pretty_amount}#{li.currency_separator_cents}#{Enum.join(cents, "")}"
          )
      end

    Map.put(li, :pretty_amount, pretty_amount)
  end

  defp handle_pretty_date(%LineItem{locale: :en_US} = li) do
    {month, day} = pad_month_and_date(li.date)
    Map.put(li, :pretty_date, "#{month}/#{day}/#{li.date.year}")
  end

  defp handle_pretty_date(%LineItem{locale: :nl_NL} = li) do
    {month, day} = pad_month_and_date(li.date)
    Map.put(li, :pretty_date, "#{day}-#{month}-#{li.date.year}")
  end

  defp handle_pretty_description(%{description: description} = li) do
    pretty_description =
      if String.length(description) > 26 do
        "" <> String.slice(description, 0, 22) <> "..."
      else
        "" <> String.pad_trailing(description, 25, " ")
      end

    Map.put(li, :pretty_description, pretty_description)
  end

  defp handle_pretty(li) do
    currency = String.pad_leading(li.pretty_amount, 13, " ")

    pretty = Enum.join([li.pretty_date, li.pretty_description, currency], " | ")

    Map.put(li, :pretty, pretty)
  end

  defp pad_month_and_date(date) do
    month = "#{date.month}" |> String.pad_leading(2, "0")
    day = "#{date.day}" |> String.pad_leading(2, "0")
    {month, day}
  end

  defp format_pretty_amount(%{locale: :en_US} = li, pretty_amount) do
    if li.amount_in_cents >= 0 do
      "#{li.currency_symbol}#{pretty_amount} "
    else
      "(#{li.currency_symbol}#{pretty_amount})"
    end
  end

  defp format_pretty_amount(%{locale: :nl_NL} = li, pretty_amount) do
    if li.amount_in_cents >= 0 do
      "#{li.currency_symbol} #{pretty_amount} "
    else
      "#{li.currency_symbol} -#{pretty_amount} "
    end
  end

  # I thought this was clear to begin with, I like this impl
  defp sort_line_items(line_items) do
    Enum.sort(line_items, fn a, b ->
      cond do
        a.date.day < b.date.day -> true
        a.date.day > b.date.day -> false
        a.description < b.description -> true
        a.description > b.description -> false
        true -> a.amount_in_cents <= b.amount_in_cents
      end
    end)
  end
end
