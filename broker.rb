# Require a few gems
require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'pg'
require 'sinatra/activerecord'

# Use a config file
config_file 'config.yml'

# Connect to the database server
ActiveRecord::Base.establish_connection(settings.databaseRoot)

def connection
  ActiveRecord::Base.connection
end

# For information purposes only
get '/' do
  send_file 'index.html'
end

# Display the service / plan metadata stored in config.yml
get '/v2/catalog' do
  content_type :json
  {services: settings.services}.to_json
end

# Create a new service instance (database)
put '/v2/service_instances/:id' do |id|
  check_id(id)

  connection.execute("create database \"D#{id}\"")
  connection.execute("create user \"U#{id}\" with password 'cf'")
  connection.execute("grant all privileges on database \"D#{id}\" to \"U#{id}\"")

  # Success
  status 201
  {:dashboard_url => "http://localhost:4567/dashboard/#{id}"}.to_json
end

# Delete a service instance (database)
delete '/v2/service_instances/:id' do |id|
  check_id(id)

  connection.execute("update pg_database set datallowconn = 'false' where datname = 'D#{id}'")
  connection.execute("select pg_terminate_backend(procpid) from pg_stat_activity where datname = 'D#{id}'")
  connection.execute("drop database \"D#{id}\"")
  connection.execute("drop user \"U#{id}\"")
  
  # Success
  {}.to_json
end

# Create a new service binding (actually just return the credentials)
put '/v2/service_instances/:instance_id/service_bindings/:id' do |instance_id, id|
  credentials = {
    :hostname => settings.databaseClientInfo['host'],
    :port => settings.databaseClientInfo['port'],
    :name => 'D' + instance_id,
    :username => 'U' + instance_id,
    :password => 'cf'
  }
  credentials[:uri] = "postgresql://#{credentials[:username]}:#{credentials[:password]}@#{credentials[:hostname]}:#{credentials[:port]}/#{credentials[:name]}"
  credentials[:jdbcUrl] = "jdbc:postgresql://#{credentials[:hostname]}:#{credentials[:port]}/#{credentials[:name]}"
  
  # Success
  {:credentials => credentials}.to_json
end

# Delete a service binding
delete '/v2/service_instances/:instance_id/service_bindings/:id' do |instance_id, id|
  # No operation is required; binding doesn't do anything in this implementation
  {}.to_json
end

# Raise an error if the specified ID is not suitable for use as a database identifier
def check_id(id)
  if id =~ /[^0-9,a-z,A-Z-]+/
    raise 'Only ids matching [0-9,a-z,A-Z-]+ are allowed'
  end
end
