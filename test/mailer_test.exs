defmodule HELF.MailerTest do
  use ExUnit.Case
  use Bamboo.Test

  alias HELF.Mailer

  defmodule RaiseMailer do
    @errors [
      Bamboo.MailgunAdapter.ApiError,
      Bamboo.MandrillAdapter.ApiError,
      Bamboo.SendgridAdapter.ApiError,
      Bamboo.SentEmail.DeliveriesError,
      Bamboo.SentEmail.NoDeliveriesError
    ]

    def deliver_now(_email),
      do: raise(Enum.random(@errors), %{params: "{}", response: "{}"})
  end

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :helf
  end

  @sender "example <example@email.com>"
  @receiver "example <example@email.com>"
  @subject "Example Subject"
  @text "Example Text"
  @html "<p>Example HTML</p>"

  describe "test mailers" do
    setup do
      email =
        Mailer.new()
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      {:ok, email: email}
    end

    test "RaiseMailer always fails", %{email: email} do
      for _ <- 1..100 do
        assert {:error, ^email} = Mailer.send(email, 200, [RaiseMailer])
      end
    end

    test "Mailer will fallback to the next mailer on the list", %{email: email} do
      for _ <- 1..100 do
        {:ok, result} =
          Mailer.send(email, 200, [RaiseMailer, RaiseMailer, TestMailer])
        assert result.mailer == TestMailer
      end
    end
  end

  describe "email sending" do
    test "write and send email without explicit composition" do
       email = Mailer.new(from: @sender, to: @receiver, subject: @subject, text: @text, html: @html)
       assert {:ok, _} = Mailer.send(email, 200)
    end

    test "write and send email with composition" do
       email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.text(@text)
        |> Mailer.html(@html)
       assert {:ok, _} = Mailer.send(email, 200)
    end
  end

  describe "email sending" do
    test "Mailer uses the configured default sender when the from field is not set" do
       email =
        Mailer.new()
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      assert email.from == Application.fetch_env!(:helf, :default_sender)
      assert {:ok, _} = Mailer.send(email, 200)
    end

    test "email doesn't require a text body" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      assert {:ok, result} = Mailer.send(email, 200)
      assert result.email == email
    end

    test "email sent with send/1 and send_async/1 are identical" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      email_sync = Mailer.send(email, 200)
      email_async =
        email
        |> Mailer.send_async(notify: true)
        |> Mailer.yield()

      assert email_async == email_sync

      email_sync = Mailer.send(email, 200, [RaiseMailer])
      email_async =
         email
         |> Mailer.send_async([notify: true], [RaiseMailer])
         |> Mailer.yield(200)
      assert email_sync == email_sync
    end
  end
end