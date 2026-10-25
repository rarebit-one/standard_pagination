require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "standard_pagination"

ENV["DATABASE_URL"] = "sqlite3::memory:"

class TestApp < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "standard_pagination_test"
  config.hosts.clear
  config.active_support.deprecation = :raise
end

TestApp.initialize!

ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :widgets do |t|
    t.string :name
    t.string :category
    t.integer :rank
  end
end

class Widget < ActiveRecord::Base
  include StandardPagination::Model
end


class WidgetsController < ActionController::Base
  include StandardPagination::Controller

  protect_from_forgery with: :exception

  rescue_from StandardError do |error|
    render plain: "catch-all: #{error.class}", status: :internal_server_error
  end

  rescue_pagination_errors html: :redirect, notice: -> { "Showing the last page" }

  def index
    pagy, widgets = paginate(Widget.order(rank: :desc), limit: params[:size] == "default" ? nil : (params[:size] || 2).to_i, client_limit: client_limit_option)

    respond_to do |format|
      format.html { render plain: widgets.map(&:name).join(","), headers: { "X-Pagination" => pagination_data(pagy).to_json } }
      format.json { render json: { names: widgets.map(&:name), pagination: pagination_data(pagy) } }
    end
  end

  def categories
    pagy, widgets = paginate(Widget.select("DISTINCT category").order(:category), limit: 1)

    render json: { categories: widgets.map(&:category), pagination: pagination_data(pagy) }
  end

  private

  def client_limit_option
    case params[:client]
    when "on" then true
    when "off" then false
    when /\A\d+\z/ then params[:client].to_i
    end
  end
end

class NotFoundWidgetsController < WidgetsController
  rescue_pagination_errors html: :not_found
end

class CustomWidgetsController < WidgetsController
  rescue_pagination_errors html: :render_custom

  private

  def render_custom(exception)
    render plain: "custom: #{exception.class}", status: :gone
  end
end

TestApp.routes.draw do
  resources :widgets, only: :index do
    get :categories, on: :collection
  end
  resources :not_found_widgets, only: :index
  resources :custom_widgets, only: :index
end
