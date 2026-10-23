# frozen_string_literal: true

DiscourseSeeTlProgress::Engine.routes.draw do
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

Discourse::Application.routes.draw { mount ::DiscourseSeeTlProgress::Engine, at: "/" }
