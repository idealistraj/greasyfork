class UserCheckingJob < ApplicationJob
  queue_as :low

  def perform(user)
    user.update(banned_at: Time.now) if user.name.include?('CX D K 58')
  end
end
