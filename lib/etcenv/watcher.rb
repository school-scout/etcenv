require 'thread'

module Etcenv
  class Watcher
    WATCH_TIMEOUT = 120

    def initialize(env, verbose: false)
      @env = env
      @verbose = verbose
      @indices = {}
      @lock = Mutex.new
    end

    attr_reader :env, :verbose

    def etcd
      env.etcd
    end

    def watch
      ch = Queue.new
      threads = env.modified_indices.map do |key, index|
        Thread.new(ch, key, index, &method(:watch_thread)).tap do |th|
          th.abort_on_exception = true
        end
      end
      report = ch.pop
      threads.each(&:kill)
      report
    end

    def auto_reload_loop
      loop do
        begin
          watch
          $stderr.puts "[watcher] reloading env #{env.root_key}" if verbose
          env.load
          yield env if block_given?
        rescue => e
          $stderr.puts "[watcher][error] Failed to reload env #{env.root_key}: #{e.inspect}"
          $stderr.puts "\t#{e.backtrace.join("\n\t")}"
        end
      end
    end

    private

    def watch_thread(ch, key, index)
      $stderr.puts "[watcher] waiting for change on #{key} (index: #{index.succ})" if verbose
      response = etcd.watch(key, recursive: true, index: [@indices[key] || 0, index].max.succ, timeout: WATCH_TIMEOUT)
      @lock.synchronize do
        # Record modified_index in watcher itself; Because the latest index may be hidden in normal response
        # e.g. unlisted keys, removed keys
        @indices[key] = response.node.modified_index
      end
      $stderr.puts "[watcher] dir #{key} has updated" if verbose
      ch << key
    rescue Net::ReadTimeout
      retry
    end
  end
end
