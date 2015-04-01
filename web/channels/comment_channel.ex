defmodule Constable.CommentChannel do
  use Constable.AuthorizedChannel
  alias Constable.Repo
  alias Constable.Announcement
  alias Constable.Comment
  alias Constable.Queries
  alias Constable.Subscription
  alias Constable.Serializers

  def handle_in("comments:create", %{"body" => body, "announcement_id" => announcement_id}, socket) do
    comment = %Comment{
      user_id: current_user_id(socket),
      body: body,
      announcement_id: announcement_id
    }
    |> Repo.insert
    |> Repo.preload([:user, :announcement])

    update_announcement_timestamps(announcement_id)
    email_subscribers(comment)

    broadcast socket, "comments:create", comment
  end

  defp email_subscribers(comment) do
    announcement_id = comment.announcement_id
    users = Repo.all(Queries.Subscription.for_announcement(announcement_id))
    |> Enum.map(fn (subscription) -> subscription.user end)

    Pact.get(:comment_mailer).created(comment, users)
  end

  defp update_announcement_timestamps(announcement_id) do
    announcement = Repo.get(Announcement, announcement_id)
    Repo.update(%{announcement | updated_at: Ecto.DateTime.utc})
  end
end