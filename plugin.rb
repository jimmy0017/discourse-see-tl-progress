# frozen_string_literal: true

# name: discourse-see-tl-progress
# about: See your own progress to each Trust Level (TL).
# meta_topic_id: TODO
# version: 0.0.1
# authors: Nate Dhaliwal
# url: TODO
# required_version: 2.7.0

enabled_site_setting :see_tl_progress_enabled

module ::DiscourseSeeTlProgress
  PLUGIN_NAME = "discourse-see-tl-progress"
end

require_relative "lib/discourse_see_tl_progress/engine"
require_relative "lib/discourse_see_tl_progress/stats_progress"
require_relative "lib/discourse_see_tl_progress/tl3_progress"
register_svg_icon "triangle-exclamation"
register_asset "stylesheets/common/progress-bar.scss"

after_initialize do
  Discourse::Application.routes.append do
    get "/u/:username/tl-progress.json" => "tl_progress#show",
        :constraints => {
          username: RouteFormat.username,
        }
  end

  DiscourseSeeTlProgress::Engine.routes.draw do
    get "/u/:username/is-locked.json" => "is_locked#show",
        :constraints => {
          username: RouteFormat.username,
        }
  end
end
