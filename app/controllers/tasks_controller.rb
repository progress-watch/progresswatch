# frozen_string_literal: true

class TasksController < ApplicationController
  def show
    render json: Tasks::SerializeForApi.call(Task.find(params[:uuid]))
  end

  def create
    task = Tasks::Create.call(
      space: Space.find(params[:space_uuid]),
      title: params[:title],
      source: params[:source],
      parent_uuid: params[:parent_uuid].presence
    )

    render json: { uuid: task.uuid }, status: :created
  end

  def update
    if request.patch?
      return render json: { error: 'use PUT: a write replaces the whole state and does not merge' },
                    status: :method_not_allowed
    end

    task = Task.find(params[:uuid])
    permitted = params.permit(:current, :end, :done, values: {})

    Tasks::Report.call(
      task,
      current: permitted[:current],
      end_value: permitted[:end],
      values: permitted[:values]&.to_h,
      done: ActiveModel::Type::Boolean.new.cast(permitted[:done]) || false
    )

    render json: Tasks::SerializeForApi.call(task.reload)
  end
end
