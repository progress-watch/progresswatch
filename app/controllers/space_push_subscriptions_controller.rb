# frozen_string_literal: true

# Web-only, like renaming a space: the browser is the only client that has a push
# endpoint to register, and an API caller would have nothing to send.
class SpacePushSubscriptionsController < WebController
  # head, not the not-found page: only fetch() calls this, and WebController's rescue
  # renders HTML — the same reason SitemapController answers with a bare status.
  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  def create
    space = Space.find(params[:uuid])

    PushSubscriptions::Create.call(space:, **subscription_params)

    head :created
  end

  def destroy
    space = Space.find(params[:uuid])

    PushSubscriptions::Delete.call(space:, endpoint: params.expect(:endpoint))

    head :no_content
  end

  private

  def subscription_params
    params.expect(subscription: %i[endpoint p256dh auth]).to_h.symbolize_keys
  end
end
