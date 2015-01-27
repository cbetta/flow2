workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads Integer(ENV['MIN_THREADS'] || 4), Integer(ENV['MAX_THREADS'] || 6)

rackup      DefaultRackup
port        ENV['PORT']     || 5000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
end
