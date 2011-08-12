require 'resque'

module Resque
  class Job
    class << self
      def create_with_spec(queue, klass, *args)
        create_without_spec(queue, klass, *args) if ResqueSpec.disabled

        raise ::Resque::NoQueueError.new("Jobs must be placed onto a queue.") if !queue
        raise ::Resque::NoClassError.new("Jobs must be given a class.") if klass.to_s.empty?
        ResqueSpec.enqueue(queue, klass, *args)
      end
      alias_method_chain :create, :spec

      def destroy_with_spec(queue, klass, *args)
        destroy_without_spec(queue, klass, *args) if ResqueSpec.disabled

        raise ::Resque::NoQueueError.new("Jobs must have been placed onto a queue.") if !queue
        raise ::Resque::NoClassError.new("Jobs must have been given a class.") if klass.to_s.empty?

        old_count = ResqueSpec.queue_by_name(queue).size

        ResqueSpec.dequeue(queue, klass, *args)

        old_count - ResqueSpec.queue_by_name(queue).size
      end
      alias_method_chain :destroy, :spec

    end
  end

  def enqueue_with_spec(klass, *args)
    enqueue_without_spec(klass, *args) if ResqueSpec.disabled

    if ResqueSpec.inline
      run_after_enqueue(klass, *args)
      Job.create(queue_from_class(klass), klass, *args)
    else
      Job.create(queue_from_class(klass), klass, *args)
      run_after_enqueue(klass, *args)
    end
  end
  alias_method_chain :enqueue, :spec

  private

  def run_after_enqueue(klass, *args)
    Plugin.after_enqueue_hooks(klass).each do |hook|
      klass.send(hook, *args)
    end
  end
end
