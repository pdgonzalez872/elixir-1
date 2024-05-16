defmodule Ledger do
  @doc """
  Format the given entries given a currency and locale
  """
  @type currency :: :usd | :eur
  @type locale :: :en_US | :nl_NL
  @type entry :: %{amount_in_cents: integer(), date: Date.t(), description: String.t()}

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

  @spec format_entries(currency(), locale(), list(entry())) :: String.t()
  def format_entries(_, locale, []) do
    header(locale)
  end

  def format_entries(currency, locale, entries) do
    header = header(locale)

    line_items =
      entries
      |> Enum.map(fn e ->
        {currency, currency_symbol, currency_separator, currency_separator_cents} =
          case locale do
            :en_US -> {:usd, "$", ",", "."}
            :nl_NL -> {:eur, "€", ".", ","}
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
      |> Enum.reduce("", fn
        [c, b, a], acc ->
          acc <> "#{c}#{b}#{a}#{li.currency_separator}"

        other, acc ->
          to_add = other |> Enum.reverse() |> Enum.join("")
          acc <> to_add
      end)

    pretty_amount =
      "#{li.currency_symbol}#{pretty_amount}#{li.currency_separator_cents}#{Enum.join(cents, "")}"

    pretty_amount =
      case amount do
        ["-" | _] ->
          "(#{pretty_amount})"

        _ ->
          "#{pretty_amount} "
      end

    Map.put(li, :pretty_amount, pretty_amount)
  end

  defp handle_pretty_date(%LineItem{locale: :en_US} = li) do
    {month, day} = pad_month_and_date(li.date)
    Map.put(li, :pretty_date, "#{month}/#{day}/#{li.date.year}")
  end

  defp handle_pretty_date(%LineItem{locale: :nl_NL} = li) do
    {month, day} = pad_month_and_date(li.date)
    Map.put(li, :pretty_date, "#{day}/#{month}/#{li.date.year}")
  end

  defp handle_pretty_description(%{description: description} = li)
       when length(description) > 26 do
    pretty_description = "" <> String.slice(description, 0, 22) <> "..."
    Map.put(li, :pretty_description, pretty_description)
  end

  defp handle_pretty_description(%{description: description} = li) do
    pretty_description = "" <> String.pad_trailing(description, 25, " ")
    Map.put(li, :pretty_description, pretty_description)
  end

  # 01/01/2015 | Freude schoner Gotterf... |   ($1,234.56)
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

  # I actually thought this was clear
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
