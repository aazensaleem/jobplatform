class SidekiqCheckJob < ApplicationJob
  queue_as :default

  def perform(message)
    Rails.logger.info("Sidekiq check job completed: #{message}")
  end
end
