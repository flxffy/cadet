defmodule CadetWeb.AssessmentsController do
  use CadetWeb, :controller

  use PhoenixSwagger

  alias Cadet.Assessments

  def index(conn, _) do
    user = conn.assigns[:current_user]
    {:ok, assessments} = Assessments.all_published_assessments(user)

    render(conn, "index.json", assessments: assessments)
  end

  def show(conn, %{"id" => assessment_id}) when is_ecto_id(assessment_id) do
    user = conn.assigns[:current_user]

    case Assessments.assessment_with_questions_and_answers(assessment_id, user) do
      {:ok, assessment} -> render(conn, "show.json", assessment: assessment)
      {:error, {status, message}} -> send_resp(conn, status, message)
    end
  end

  swagger_path :index do
    get("/assessments")

    summary("Get a list of all assessments")

    security([%{JWT: []}])

    produces("application/json")

    response(200, "OK", Schema.ref(:AssessmentsList))
    response(401, "Unauthorised")
  end

  swagger_path :show do
    get("/assessments/{assessmentId}")

    summary("Get information about one particular assessment.")

    security([%{JWT: []}])

    produces("application/json")

    parameters do
      assessmentId(:path, :integer, "assessment id", required: true)
    end

    response(200, "OK", Schema.ref(:Assessment))
    response(400, "Missing parameter(s) or invalid assessmentId")
    response(401, "Unauthorised")
  end

  def swagger_definitions do
    %{
      AssessmentsList:
        swagger_schema do
          description("A list of all assessments")
          type(:array)
          items(Schema.ref(:AssessmentOverview))
        end,
      AssessmentOverview:
        swagger_schema do
          properties do
            id(:integer, "The assessment id", required: true)
            title(:string, "The title of the assessment", required: true)
            type(:string, "Either mission/sidequest/path/contest", required: true)
            shortSummary(:string, "Short summary", required: true)
            openAt(:string, "The opening date", format: "date-time", required: true)
            closeAt(:string, "The closing date", format: "date-time", required: true)

            attempted(
              :boolean,
              "Whether the assessment has been attempted by the current user",
              required: true
            )

            maximumEXP(
              :integer,
              "The maximum amount of XP to be earned from this assessment",
              required: true
            )

            coverImage(:string, "The URL to the cover picture", required: true)
          end
        end,
      Assessment:
        swagger_schema do
          properties do
            id(:integer, "The assessment id", required: true)
            title(:string, "The title of the assessment", required: true)
            type(:string, "Either mission/sidequest/path/contest", required: true)
            longSummary(:string, "Long summary", required: true)
            missionPDF(:string, "The URL to the assessment pdf")

            questions(Schema.ref(:Questions), "The list of questions for this assessment")
          end
        end,
      Questions:
        swagger_schema do
          description("A list of questions")
          type(:array)
          items(Schema.ref(:Question))
        end,
      Question:
        swagger_schema do
          properties do
            id(:integer, "The question id", required: true)
            type(:string, "The question type (mcq/programming)", required: true)
            content(:string, "The question content", required: true)

            choices(
              Schema.new do
                type(:array)
                items(Schema.ref(:MCQChoice))
              end,
              "MCQ choices if question type is mcq"
            )

            solution(:integer, "Solution to a mcq question if it belongs to path assessment")

            answer(
              :string_or_integer,
              "Previous answer for this quesiton (string/int) depending on question type",
              required: true
            )

            library(
              Schema.ref(:Library),
              "The library used for this question"
            )

            solution_template(:string, "Solution template for programming questions")
          end
        end,
      MCQChoice:
        swagger_schema do
          properties do
            content(:string, "The choice content", required: true)
            hint(:string, "The hint", required: true)
          end
        end,
      Library:
        swagger_schema do
          properties do
            chapter(:integer)

            globals(
              Schema.new do
                type(:array)

                items(
                  Schema.new do
                    type(:string)
                  end
                )
              end
            )

            externals(
              Schema.new do
                type(:array)

                items(
                  Schema.new do
                    type(:string)
                  end
                )
              end
            )

            files(
              Schema.new do
                type(:array)

                items(
                  Schema.new do
                    type(:string)
                  end
                )
              end
            )
          end
        end
    }
  end
end