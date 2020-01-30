defmodule OutcryWeb.LiveAuth do
  @moduledoc """
  Handle Pow user in LiveView.

  This allows the LiveView to get the user ID of the currently logged in
  user. The session validity is checked once, when the user first
  connects, and not checked thereafter. This means that changes to the
  session validity (e.g., logging out) will NOT affect the LiveView.

  TODO: revisit this if Pow ever adds this feature.
  <https://github.com/danschultzer/pow/issues/271>
  """
  defmacro __using__(opts) do
    config = [otp_app: opts[:otp_app]]
    session_id_key = Pow.Plug.prepend_with_namespace(config, "auth")

    config = config ++ [session_id_key: session_id_key]

    quote do
      @pow_config unquote(Macro.escape(config))

      def get_user_id(session) do
        unquote(__MODULE__).get_user_id(session, @pow_config)
      end
    end
  end

  def get_user_id(session, config) do
    with {:ok, session_id} <- Map.fetch(session, config[:session_id_key]),
         {%{id: id}, _meta} <- credential_by_session_id(config, session_id) do
      {:ok, id}
    else
      _ -> :error
    end
  end

  defp credential_by_session_id(config, session_id) do
    Pow.Store.CredentialsCache.get(
      [backend: get_cache_store_backend(config)],
      session_id
    )
  end

  defp get_cache_store_backend(config) do
    Pow.Config.get(Application.get_env(config[:otp_app], :pow), :cache_store_backend)
  end
end
