require "spec_helper"
require "redis"

describe RedisLock do
  let(:locking_key)         { "redis-lock-locking-key" }
  let(:redis)               { Redis.new }
  let(:unlocked_redis_lock) { RedisLock.new(redis, locking_key) }
  let(:locked_redis_lock)   { unlocked_redis_lock.tap(&:lock) }

  before { redis.flushdb }

  context "#lock when unlocked" do
    subject { unlocked_redis_lock }

    it "locks when a lock can be acquired" do
      subject.should_not be_locked
      subject.lock
      subject.should be_locked
    end
  end

  context "#lock when locked" do
    subject { locked_redis_lock }
    before  { subject }

    it "raises an exception if the lock cannot be acquired" do
      expect do
        subject.lock
      end.to raise_error(RedisLock::LockNotAcquired,
                         "Unable to acquire lock for key: #{locking_key}")
    end

    it "sleeps for the specified amount" do
      Kernel.stubs(:sleep)

      expect do
        subject.retry(20.times).every(2).lock
      end.to raise_error(RedisLock::LockNotAcquired)

      Kernel.should have_received(:sleep).with(2).times(20)
    end

    it "retries a set number of times" do
      redis.stubs(:setnx => false)

      expect do
        subject.retry(5.times).lock
      end.to raise_error(RedisLock::LockNotAcquired)

      redis.should have_received(:setnx).times(5)
      subject.should be_locked
    end

    it "resets number of retries after acquiring a lock" do
      subject.retry(5.times)

      setnx_responses = [false, false, true, false, false, false, false, true]
      redis.stubs(:setnx).returns(*setnx_responses)

      expect do
        subject.lock
      end.to_not raise_error(RedisLock::LockNotAcquired)

      subject.unlock

      expect do
        subject.lock
      end.to_not raise_error(RedisLock::LockNotAcquired)
    end
  end

  context "#unlock when locked" do
    subject { locked_redis_lock }

    it "knows it is not locked" do
      subject.unlock
      subject.should_not be_locked
    end

    it "raises an exception if it can't unlock correctly" do
      redis.del(subject.key)

      expect do
        subject.unlock
      end.to raise_error(RedisLock::UnlockFailure, "Unable to unlock key: #{locking_key}")
    end
  end

  context "#unlock when unlocked" do
    subject { unlocked_redis_lock }

    it "knows it is not locked" do
      subject.unlock
      subject.should_not be_locked
    end
  end

  context "#lock_for_update when a lock can be acquired" do
    subject { unlocked_redis_lock }

    it "runs a block" do
      result = "changes within lock"

      subject.lock_for_update do
        result = "changed!"
      end

      result.should == "changed!"
    end

    it "locks the key during execution" do
      subject.lock_for_update do
        subject.should be_locked
      end
    end

    it "unlocks the key after completion" do
      subject.lock_for_update { }
      subject.should_not be_locked
    end

    it "unlocks when the block raises" do
      expect do
        subject.lock_for_update do
          raise RuntimeError, "something went wrong!"
        end
      end.to raise_error(RuntimeError, "something went wrong!")

      subject.should_not be_locked
    end

    it "runs the block but raises if unlocking failed" do
      result = "changes within lock"

      expect do
        subject.lock_for_update do
          redis.del(subject.key)
          result = "changed!"
        end
      end.to raise_error(RedisLock::UnlockFailure)

      result.should == "changed!"
    end
  end

  context "#lock_for_update when a lock cannot be acquired" do
    subject { locked_redis_lock }

    it "does not run the block" do
      result = "doesn't change within lock"

      expect do
        subject.lock_for_update do
          result = "changed!"
        end
      end.to raise_error(RedisLock::LockNotAcquired)

      result.should == "doesn't change within lock"
    end

    it "remains locked" do
      expect { subject.lock_for_update { } }.to raise_error(RedisLock::LockNotAcquired)

      subject.should be_locked
    end
  end
end

describe RedisLock::Retry, "defaults" do
  its(:count)    { should == 10 }
  its(:interval) { should == 0.2 }
  its(:attempts) { should be_zero }
end
