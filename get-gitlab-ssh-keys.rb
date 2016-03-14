#!env ruby

require 'faraday'
require 'json'
require 'ssh-fingerprint'
require 'pp'

#
class GitlabUtils
  def initialize
    @private_token = ENV['GITLAB_TOKEN']
    @conn = Faraday.new(url: ENV['GITLAB_URL']) do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end
  end

  # Get all user ids
  def user_ids
    page = 1
    per_page = 100
    user_ids = []
    puts 'collecting all user ids'
    loop do
      response = @conn.get api_url('/users'),
                           { page: page, per_page: per_page }.merge(token)
      raise 'Error Retrieving user_ids' if response.status != 200
      ids = JSON.parse(response.body).collect { |u| u['id'] }
      user_ids.concat(ids)
      break if ids.size < per_page
      page += 1
    end
    puts 'returning now the user ids'
    user_ids.sort
  end

  def get_user_email(user_id)
    response = @conn.get api_url("/users/#{user_id}"), token
    if response.status != 200
      raise "Error retrieving email for user_id = #{user_id}"
    end

    JSON.parse(response.body)['email']
  end

  def user_ssh_keys(user_id)
    ssh_keys = []
    response = @conn.get api_url("/users/#{user_id}/keys"), token
    if response.status != 200
      raise "Error retrieving keys for user_id = #{user_id}"
    end
    JSON.parse(response.body).each do |key|
      ssh_keys << SSHFingerprint.compute(key['key'])
    end
    ssh_keys
  end

  def print_ssh_list
    user_ids.each do |user_id|
      ssh_keys = user_ssh_keys(user_id)
      next if ssh_keys.empty?
      email = get_user_email(user_id)
      ssh_keys.each do |key|
        puts "#{email} - #{user_id} - #{key}"
      end
    end
  end

  def api_url(resource)
    "/api/v3/#{resource}"
  end

  def token
    { private_token:  @private_token }
  end
end

GitlabUtils.new.print_ssh_list
