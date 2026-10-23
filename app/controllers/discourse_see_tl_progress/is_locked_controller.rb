# frozen_string_literal: true

module DiscourseSeeTlProgress
  class IsLockedController < ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def show
      raise Discourse::NotFound unless SiteSetting.show_locked_at_trust_level
      user = User.find_by_username(params[:username])
      raise Discourse::NotFound unless user
      raise Discourse::InvalidAccess unless current_user == user || current_user.staff?

      render json: {
               is_locked: user.manual_locked_trust_level?,
               locked_at_trust_level: user.manual_locked_trust_level.to_i,
             }
    end
  end
end
