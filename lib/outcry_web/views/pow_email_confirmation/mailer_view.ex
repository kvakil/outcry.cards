defmodule OutcryWeb.PowEmailConfirmation.MailerView do
  use OutcryWeb, :mailer_view

  def subject(:email_confirmation, _assigns), do: "Confirm your email address"
end
