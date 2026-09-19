# frozen_string_literal: true

class SpacePushSubscriptionsController < WebController
  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  rescue_from PushDelivery::Apns::InvalidDevice, ActiveRecord::RecordInvalid do
    head :unprocessable_content
  end

  def create
    space = Space.find(params[:uuid])

    subscription = PushSubscriptions::Create.call(space:, **subscription_params)

    render json: { id: subscription.uuid }, status: :created
  end

  def destroy
    space = Space.find(params[:uuid])

    PushSubscriptions::Delete.call(space:, endpoint: params[:apns] ? apns_endpoint : params.expect(:endpoint))

    head :no_content
  end

  private

  def subscription_params
    return { endpoint: apns_endpoint } if params[:apns]

    params.expect(subscription: %i[endpoint p256dh auth]).to_h.symbolize_keys
  end

  def apns_endpoint
    device = params.expect(apns: %i[token environment])

    PushDelivery::Apns.endpoint(token: device[:token], environment: device[:environment])
  end
end
