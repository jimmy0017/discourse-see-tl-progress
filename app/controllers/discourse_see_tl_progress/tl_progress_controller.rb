# frozen_string_literal: true

module DiscourseSeeTlProgress
  class TlProgressController < ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def show
      user = User.find_by_username(params[:username])
      raise Discourse::NotFound unless user
      raise Discourse::InvalidAccess unless current_user == user || current_user.staff?

      render json: { stats_progress: ::DiscourseSeeTlProgress::StatsProgress.new(user).stats }
    end
  end
end
