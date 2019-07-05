defmodule Cadet.Chat.Room do
  @moduledoc """
  Contains logic pertaining to chatroom creation to supplement ChatKit, an external service engaged for Source Academy.
  ChatKit's API can be found here: https://pusher.com/docs/chatkit
  """

  require Logger

  import Ecto.Query

  alias Cadet.Repo
  alias Cadet.Assessments.{Answer, Submission}
  alias Cadet.Accounts.User
  alias Cadet.Chat.Token

  @instance_id :cadet |> Application.fetch_env!(:chat) |> Keyword.get(:instance_id)

  @doc """
  Creates a chatroom for every answer, and updates db with the chatroom id.
  Takes in Submission struct
  """
  def create_rooms(
        submission = %Submission{
          id: submission_id,
          student_id: student_id
        }
      ) do
    user = User |> where(id: ^student_id) |> Repo.one()

    Answer
    |> where(submission_id: ^submission_id)
    |> Repo.all()
    |> Enum.filter(fn answer ->
      answer.comment == "" or answer.comment == nil
    end)
    |> Enum.each(fn answer -> create_rooms(submission, answer, user) end)
  end

  @doc """
  Creates a chatroom for every answer, and updates db with the chatroom id.
  Takes in Submission, Answer and User struct
  """
  def create_rooms(
        %Submission{
          assessment_id: assessment_id
        },
        answer = %Answer{question_id: question_id},
        user
      ) do
    with {:ok, %{"id" => room_id}} <- create_room(assessment_id, question_id, user) do
      answer
      |> Answer.comment_changeset(%{
        comment: room_id
      })
      |> Repo.update()
    end
  end

  defp create_room(
         assessment_id,
         question_id,
         %User{
           id: student_id,
           nusnet_id: nusnet_id
         }
       ) do
    HTTPoison.start()

    url = "https://us1.pusherplatform.io/services/chatkit/v4/#{@instance_id}/rooms"

    {:ok, token} = Token.get_superuser_token()
    headers = [Authorization: "Bearer #{token}"]

    body =
      Poison.encode!(%{
        "name" => "#{nusnet_id}_#{assessment_id}_Q#{question_id}",
        "private" => true,
        "user_ids" => get_staff_admin_user_ids() ++ [to_string(student_id)]
      })

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} ->
        Poison.decode(body)

      {:ok, _} ->
        {:error, nil}

      {:error, %HTTPoison.Error{reason: error}} ->
        Logger.error("error: #{inspect(error, pretty: true)}")
        {:error, nil}
    end
  end

  defp get_staff_admin_user_ids do
    User
    |> where([u], u.role in ^[:staff, :admin])
    |> Repo.all()
    |> Enum.map(fn user -> to_string(user.id) end)
  end
end
