defmodule Outcry.Rater do
  use GenServer

  @nostate []

  def start_link(@nostate) do
    GenServer.start_link(__MODULE__, @nostate, name: __MODULE__)
  end

  @impl true
  def init(@nostate) do
    {:ok, @nostate}
  end

  @default_rating 0
  defp get_user_rating(user_id) do
    import Ecto.Query
    alias Outcry.{Repo, Users.User}

    with "user:" <> user_id <- user_id,
         rating when not is_nil(rating) <-
           Repo.one!(from u in User, where: u.id == ^user_id, select: u.rating) do
      rating
    else
      _ -> @default_rating
    end
  end

  defp map_mean(map) do
    Enum.sum(Map.values(map)) / map_size(map)
  end

  defp subtract_from_map(map, n) do
    Map.new(map, fn {k, v} -> {k, v - n} end)
  end

  @ema_weight 0.05
  defp compute_ratings(final_scores) do
    expected_scores = Map.new(final_scores, fn {id, _} -> {id, get_user_rating(id)} end)
    mean_rating = map_mean(expected_scores)
    demeaned_ratings = subtract_from_map(expected_scores, mean_rating)

    mean_score = map_mean(final_scores)
    demeaned_scores = subtract_from_map(final_scores, mean_score)

    Map.merge(demeaned_scores, demeaned_ratings, fn _, s, r ->
      s * @ema_weight + r * (1 - @ema_weight) + mean_rating
    end)
  end

  defp update_ratings(ratings) do
    import Ecto.Query
    alias Outcry.{Repo, Users.User}

    ratings |> Enum.each(fn {user_id, rating} ->
      with "user:" <> user_id <- user_id,
           user <- Repo.one!(from u in User, where: u.id == ^user_id),
           {:ok, _} <- User.update_rating(user, rating) do
        nil
      end
    end)
  end

  @impl true
  def handle_cast(%{score_info: score_info, pid_to_player_id: pid_to_player_id}, @nostate) do
    final_scores =
      Map.new(pid_to_player_id, fn {pid, player_id} ->
        {
          player_id,
          score_info.final_scores[pid]
        }
      end)
    new_ratings = compute_ratings(final_scores)
    update_ratings(new_ratings)
    {:noreply, @nostate}
  end

  def rate_game(info) do
    GenServer.cast(__MODULE__, info)
  end
end
