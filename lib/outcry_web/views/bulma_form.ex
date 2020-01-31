defmodule OutcryWeb.BulmaForm do
  alias Phoenix.HTML.{Form, Tag}

  defp add_class(opts, class) do
    Keyword.update(opts, :class, class, &(&1 <> " #{class}"))
  end

  defp control_div(element) do
    Tag.content_tag(:div, element, class: "control")
  end

  defp highlight_if_error(opts, form, field) do
    if Enum.empty?(Keyword.get_values(form.errors, field)) do
      opts
    else
      opts |> add_class("is-danger")
    end
  end

  def flash_if_error(changeset) do
    if changeset.action do
      Tag.content_tag(
        :div,
        Tag.content_tag(
          :p,
          OutcryWeb.ErrorHelpers.translate_error(
            {"Oops, something went wrong! Please check the errors below.", []}
          )
        ),
        class: "notification is-danger"
      )
    else
      {:safe, ""}
    end
  end

  def label(form, field, opts \\ []) do
    Form.label(form, field, opts |> add_class("label"))
  end

  defp make_input(form_fn, form, field, opts) do
    form_fn.(form, field, opts |> add_class("input") |> highlight_if_error(form, field))
    |> control_div()
  end

  def text_input(form, field, opts \\ []) do
    make_input(&Form.text_input/3, form, field, opts)
  end

  def password_input(form, field, opts \\ []) do
    make_input(&Form.password_input/3, form, field, opts)
  end

  def submit(value, opts \\ []) do
    Form.submit(value, opts |> add_class("button"))
    |> control_div()
  end
end
