require 'active_support/concern'

class RedisLock
  module Concern
    module Lockable
      extend ActiveSupport::Concern
      class RedisNotConfigured < Exception; end

      # Finds the lock for the given `key`
      def find_or_create_lock(key)
        # If a locker doesn't exist, make one
        @redis_lock_locker ||= {}

        # If Redis is not configured, raise an error
        raise RedisNotConfigured if @redis_lock_redis.nil? and $redis.nil?

        # Find the key in the locker. If it doesn't exist, create one
        @redis_lock_locker[key] ||= RedisLock.new(@redis_lock_redis || $redis, key)
      end

      def lock(key, options = {})
        locker = find_or_create_lock(key)

        unless options.empty?
          locker.retry(options[:retry]) if options.keys.include? :retry
          locker.every(options[:every]) if options.keys.include? :every
        end

        if block_given?
          locker.lock_for_update do
            # lock was acquired
            yield
          end
        else
          locker.lock
        end
      end

      def unlock(key)
        locker = find_or_create_lock(key)
        locker.unlock
      end

      def locked?(key)
        locker = find_or_create_lock(key)
        locker.locked?
      end
    end
  end
end
