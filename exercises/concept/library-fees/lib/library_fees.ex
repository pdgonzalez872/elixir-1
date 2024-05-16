defmodule LibraryFees do
  def datetime_from_string(string) when is_binary(string) do
    {:ok, n} = NaiveDateTime.from_iso8601(string)
    n
  end

  def before_noon?(%NaiveDateTime{} = d) do
    noon_that_day = NaiveDateTime.new!(d.year, d.month, d.day, 12, 0, 0)

    d
    |> NaiveDateTime.diff(noon_that_day, :second)
    |> case do
      result when result >= 0 -> false
      _ -> true
    end
  end

  def return_date(%NaiveDateTime{} = d) do
    add_days_fun = fn d, days ->
      d
      |> NaiveDateTime.add(days, :day)
      |> NaiveDateTime.to_date()
    end

    d
    |> before_noon?()
    |> case do
      true -> add_days_fun.(d, 28)
      false -> add_days_fun.(d, 29)
    end
  end

  def days_late(%Date{} = planned_return_date, %NaiveDateTime{} = actual_return_datetime) do
    planned_return_date
    |> Date.diff(NaiveDateTime.to_date(actual_return_datetime))
    |> case do
      0 ->
        0

      days when days < 0 ->
        abs(days)

      _early ->
        0
    end
  end

  def monday?(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.to_erl()
    |> then(fn {to_check, _} -> to_check end)
    |> :calendar.day_of_the_week()
    |> case do
      1 -> true
      _ -> false
    end
  end

  def calculate_late_fee(checkout, return, rate) do
    checkout = checkout |> datetime_from_string()
    return = datetime_from_string(return)

    date_diff = days_late(NaiveDateTime.to_date(checkout), return)
    days_to_charge = date_diff - 28

    cond do
      date_diff < 28 ->
        0

      date_diff == 28 and not before_noon?(checkout) ->
        0

      date_diff == 29 and not before_noon?(checkout) ->
        0

      date_diff == 30 and not before_noon?(checkout) ->
        (days_to_charge - 1) * rate

      date_diff == 29 and before_noon?(checkout) ->
        days_to_charge * rate

      monday?(return) ->
        trunc(days_to_charge * (rate * 0.5))

      true ->
        rate * days_to_charge
    end
  end
end
