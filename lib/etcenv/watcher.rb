require 'thread'

module Etcenv
  class Watcher
    def initialize(env, verbose: false)
      @env = env
      @verbose = verbose
    end

    attr_reader :env, :verbose

    def etcd
      env.etcd
    end

    def watch
      ch = Queue.new
      threads = env.modified_indices.map do |key, index|
        Thread.new do
          $stderr.puts "[watcher] waiting for change on #{key} (index: #{index.succ})" if verbose
          etcd.watch(key, recursive: true, index: index.succ)
          $stderr.puts "[watcher] dir #{key} has updated" if verbose
          ch << key
        end
      end
      report = ch.pop
      threads.each(&:kill)
      report
    end

    def auto_reload_loop
      loop do
        watch
        $stderr.puts "[watcher] reloading env #{env.root_key}" if verbose
        env.load
        yield env if block_given?
      end
    end
  end
end