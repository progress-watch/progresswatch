# frozen_string_literal: true

class SpacePushSubscriptionsController < WebController
  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  rescue_from PushDelivery::Apns::InvalidDevice, PushDelivery::Fcm::InvalidDevice,
              PushDelivery::WebPush::InvalidEndpoint, ActiveRecord::RecordInvalid do
    head :unprocessable_content
  end

  def create
    space = Space.find(params[:uuid])

    subscription = PushSubscriptions::Create.call(space:, **subscription_params)

    render json: { id: subscription.uuid }, status: :created
  end

  def destroy
    space = Space.find(params[:uuid])

    PushSubscriptions::Delete.call(space:, endpoint: native? ? native_endpoint : params.expect(:endpoint))

    head :no_content
  end

  private

  def subscription_params
    return { endpoint: native_endpoint } if native?

    browser = params.expect(subscription: %i[endpoint p256dh auth])

    { endpoint: PushDelivery::WebPush.endpoint(browser[:endpoint]), p256dh: browser[:p256dh], auth: browser[:auth] }
  end

  def native?
    params[:apns] || params[:fcm]
  end

  def native_endpoint
    return PushDelivery::Fcm.endpoint(token: params.expect(fcm: [:token])[:token]) if params[:fcm]

    device = params.expect(apns: %i[token environment])

    PushDelivery::Apns.endpoint(token: device[:token], environment: device[:environment])
  end
end
