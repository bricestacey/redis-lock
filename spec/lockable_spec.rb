require "spec_helper"
require "redis"
require "redis_lock/concerns/lockable"

describe RedisLock::Concern::Lockable do
  let(:redis)               { Redis.new }
  let(:locking_key)         { "lockable-locking-key" }
  let(:model) do
    class Foo
      include RedisLock::Concern::Lockable
    end
  end
  let(:expected_return_value)   { mock('expected return value') }

  subject { model.new }

  context ".find_or_create_lock when no locker" do
    it "instantiates a locker" do
      subject.instance_variable_get(:@redis_lock_locker).should eq(nil)
      subject.find_or_create_lock(locking_key)
      subject.instance_variable_get(:@redis_lock_locker).should be_a(Hash)
    end
  end

  context "#find_or_create_lock with a locker but no lock" do
    before  { subject.instance_variable_set(:@redis_lock_locker, {}) }

    it "adds a lock to the locker" do
      subject.find_or_create_lock(locking_key)
      subject.instance_variable_get(:@redis_lock_locker).should have(1).items
      subject.instance_variable_get(:@redis_lock_locker)[locking_key].should be_a(RedisLock)
    end
  end

  context "#find_or_create_lock with a locker and the lock" do
    before { subject.instance_variable_set(:@redis_lock_locker, {locking_key => RedisLock.new(redis, locking_key)}) }

    it "finds the lock" do
      expected_lock = subject.instance_variable_get(:@redis_lock_locker)[locking_key]
      subject.find_or_create_lock(locking_key).should eq(expected_lock)
    end

    it "doesn't add another lock to the locker" do
      expect do 
        subject.find_or_create_lock(locking_key) 
      end.should_not change{subject.instance_variable_get(:@redis_lock_locker).count}
    end
  end

  context "#lock with options" do
    context "given a retry option" do
      before { @options = { retry: 5.times } }

      it "calls #retry on the appropriate lock" do
        subject.find_or_create_lock(locking_key).expects(:retry).with(@options[:retry])
        subject.find_or_create_lock(locking_key).expects(:lock).returns(expected_return_value)

        subject.lock(locking_key, retry: @options[:retry]).should eq(expected_return_value)
      end
    end

    context "given an every option" do
      before { @options = { every: 5 } }

      it "calls #every on the appropriate lock" do
        subject.find_or_create_lock(locking_key).expects(:every).with(@options[:every])
        subject.find_or_create_lock(locking_key).expects(:lock).returns(expected_return_value)

        subject.lock(locking_key, @options).should eq(expected_return_value)
      end
    end

    context "given multiple options" do
      before { @options = { retry: 5.times, every: 5 } }

      it "calls #retry and #every for the appropriate lock" do
        subject.find_or_create_lock(locking_key).expects(:every).with(@options[:every])
        subject.find_or_create_lock(locking_key).expects(:retry).with(@options[:retry])
        subject.find_or_create_lock(locking_key).expects(:lock).returns(expected_return_value)

        subject.lock(locking_key, @options).should eq(expected_return_value)
      end
    end
  end

  context "#lock without a block" do
    it "calls #lock on the appropriate RedisLock" do
      subject.find_or_create_lock(locking_key).expects(:lock).returns(expected_return_value)

      subject.lock(locking_key).should eq(expected_return_value)
    end
  end

  context "#lock when given a block" do
    it "calls #lock on the appropriate RedisLock and passes the block" do
      foo = proc { "foo" }
      subject.find_or_create_lock(locking_key).expects(:lock_for_update).with(&foo)

      subject.lock(locking_key, &foo)
    end
  end

  context "#unlock" do
    it "calls #unlock on the appropriate RedisLock" do
      subject.find_or_create_lock(locking_key).expects(:unlock).returns(expected_return_value)

      subject.unlock(locking_key).should eq(expected_return_value)
    end
  end

  context "#locked?" do
    it "calls #locked? on the appropriate RedisLock" do
      subject.find_or_create_lock(locking_key).expects(:locked?).returns(expected_return_value)

      subject.locked?(locking_key).should eq(expected_return_value)
    end
  end
end
