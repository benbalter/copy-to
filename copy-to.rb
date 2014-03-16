require 'octokit'
require 'sinatra_auth_github'
require 'dotenv'
require 'open3'
require 'redis'
require 'json'
require 'securerandom'
require 'fileutils'
require 'rack/coffee'

Dotenv.load

module CopyTo
  class App < Sinatra::Base
    enable :sessions

    set :github_options, {
      :scopes    => "repo",
      :secret    => ENV['GITHUB_CLIENT_SECRET'],
      :client_id => ENV['GITHUB_CLIENT_ID'],
    }

    register Sinatra::Auth::Github
    use Rack::Coffee, root: 'public', urls: '/assets/javascripts'

    use Rack::Session::Cookie, {
      :http_only => true,
      :secret => ENV['SESSION_SECRET'] || SecureRandom.hex
    }

    configure :production do
      require 'rack-ssl-enforcer'
      use Rack::SslEnforcer
    end

    def root
      @root ||= File.expand_path File.dirname(__FILE__)
    end

    def user
      env['warden'].user
    end

    def client
      Octokit::Client.new :access_token => user.token
    end

    def nwo
      "#{params[:owner]}/#{params[:repo]}" unless params[:owner].nil? || params[:repo].nil?
    end

    def repo
      @repo ||= begin
        client.repo nwo unless nwo.nil?
      rescue Octokit::NotFound
        nil
      end
    end

    def branches
      @branches ||= client.branches nwo unless repo.nil?
    end

    def locals
     {
        :repo          => repo,
        :user          => user,
        :branches      => branches,
        :owner         => params[:owner],
        :dest_repo     => params[:dest_repo],
        :source_branch => params[:source_branch],
        :dest_branch   => params[:dest_branch],
        :repo_name     => params[:repo],
        :nwo           => nwo
      }
    end

    def render_template(template, error=nil)
      halt erb template, :layout => :layout, :locals => locals.merge(:error => error, :template => template)
    end

    def repo_path
      @repo_path ||= File.expand_path "./tmp/#{SecureRandom.hex}", root
    end

    def destination_remote
      "https://#{user.token}:x-oauth-basic@github.com/#{params[:owner]}/#{params[:dest_repo]}"
    end

    def cache_params
      session[:params] = params.to_json
    end

    def uncache_params
      params.merge! JSON.parse(session.delete(:params))
    end

    def repo_exists?(name)
      nwo = "#{user.login}/#{name}"
      begin
        client.repository nwo
      rescue Octokit::NotFound
        false
      end
    end

    def clone_and_push
      render_template :copy, "Destination repository already exists" if repo_exists? params[:dest_repo]
      FileUtils.rm_rf repo_path
      begin
        client.create_repository params[:dest_repo], :description => repo.description
        Open3.capture2 "git", "clone", "--quiet", "--branch", params[:source_branch], "https://github.com/#{nwo}", repo_path
        Dir.chdir repo_path
        Open3.capture2 "git", "remote", "add", "downstream", destination_remote
        Open3.capture2 "git", "push", "downstream", params[:dest_branch]
        render_template :success
      ensure
        FileUtils.rm_rf repo_path
      end
    end

    get '/' do
      authenticate!
      render_template :index
    end

    get '/:owner/:repo' do
      if session[:params]
        uncache_params
        clone_and_push
      else
        authenticate!
        if repo.nil?
          render_template :not_found
        else
          render_template :copy
        end
      end
    end

    post "/:owner/:repo" do
      cache_params
      authenticate!
    end

  end
end
