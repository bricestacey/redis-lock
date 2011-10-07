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

      def lock(key)
        locker = find_lock(key)

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
