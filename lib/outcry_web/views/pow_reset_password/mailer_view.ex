defmodule OutcryWeb.PowResetPassword.MailerView do
  use OutcryWeb, :mailer_view

  def subject(:reset_password, _assigns), do: "Reset password link"
end
