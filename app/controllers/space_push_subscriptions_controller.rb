# frozen_string_literal: true

class SpacePushSubscriptionsController < WebController
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
