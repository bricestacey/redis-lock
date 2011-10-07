require 'active_support/concern'

class RedisLock
  module Concerns
    module Lockable
      extend ActiveSupport::Concern

      # Finds the lock for the given `key`
      def find_lock(key)
        # If a locker doesn't exist, make one
        @redis_lock_locker ||= {}

        # Find the key in the locker. If it doesn't exist, create one
        @redis_lock_locker[key] ||= RedisLock.new(Redis.new, key)
      end

      def lock(key, options = {})
        locker = find_lock(key)

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
        locker = find_lock(key)
        locker.unlock
      end
    end
  end
end
