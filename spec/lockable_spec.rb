require "spec_helper"
require "redis"
require "redis_lock/concerns/lockable"

describe RedisLock::Concerns::Lockable do
  let(:redis)               { Redis.new }
  let(:locking_key)         { "lockable-locking-key" }
  let(:model) do
    class Foo
      include ActiveSupport::Concern
      include RedisLock::Concerns::Lockable
    end
  end
  subject { model.new }

  before(:each) do 
    RedisLock.any_instance.stubs(:lock)
    RedisLock.any_instance.stubs(:unlock)
  end

  context ".find_lock when no locker" do
    it "instantiates a locker" do
      subject.instance_variable_get(:@redis_lock_locker).should eq(nil)
      subject.find_lock(locking_key)
      subject.instance_variable_get(:@redis_lock_locker).should be_a(Hash)
    end

    it "adds a lock to the locker" do
      subject.find_lock(locking_key)
      subject.instance_variable_get(:@redis_lock_locker).should have(1).items
      subject.instance_variable_get(:@redis_lock_locker)[locking_key].should be_a(RedisLock)
    end
  end

  context "#find_lock with a locker but no lock" do
    before  { subject.instance_variable_set(:@redis_lock_locker, {}) }

    it "adds a lock to the locker" do
      subject.find_lock(locking_key)
      subject.instance_variable_get(:@redis_lock_locker).should have(1).items
      subject.instance_variable_get(:@redis_lock_locker)[locking_key].should be_a(RedisLock)
    end
  end

  context "#find_lock with a locker and the lock" do
    before { subject.instance_variable_set(:@redis_lock_locker, {locking_key => RedisLock.new(redis, locking_key) }) }

    it "finds the lock" do
      expected_lock = subject.instance_variable_get(:@redis_lock_locker)[locking_key]
      subject.find_lock(locking_key).should eq(expected_lock)
    end

    it "doesn't add another lock to the locker" do
      expect { subject.find_lock(locking_key) }.should_not change{subject.instance_variable_get(:@redis_lock_locker).count}
    end
  end

  context "#lock with options" do
    context "given a retry option" do
      it "calls #retry on the appropriate lock" do
        options = { retry: 5.times }
        subject.find_lock(locking_key).expects(:retry).with(options[:retry])
        subject.lock(locking_key, retry: options[:retry])
      end
    end
    context "given an every option" do
      it "calls #every on the appropriate lock" do
        subject.find_lock(locking_key).expects(:every).with(5)
        subject.lock(locking_key, every: 5)
      end
    end
    context "given multiple options" do
      it "calls #retry and #every for the appropriate lock" do
        options = { retry: 5.times, every: 5 }
        subject.find_lock(locking_key).expects(:every).with(options[:every])
        subject.find_lock(locking_key).expects(:retry).with(options[:retry])
        subject.lock(locking_key, retry: options[:retry], every: options[:every])
      end
    end
  end

  context "#lock without a block" do
    it "calls #lock on the appropriate RedisLock" do
      subject.find_lock(locking_key).expects(:lock)
      subject.lock(locking_key)
    end
  end

  context "#lock when given a block" do
    it "calls #lock on the appropriate RedisLock and passes the block" do
      foo = proc { "foo" }
      subject.find_lock(locking_key).expects(:lock_for_update).with(&foo)

      subject.lock(locking_key) do
        "foo"
      end
    end
  end

  context "#unlock" do
    it "calls #unlock on the appropriate RedisLock" do
      subject.find_lock(locking_key).expects(:unlock)
      subject.unlock(locking_key)
    end
  end
end
