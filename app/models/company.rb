class Company < ApplicationRecord
  belongs_to :user
  has_many :jobs, dependent: :destroy

  validates :name, presence: true

  after_update_commit :sync_jobs_for_search, if: :saved_change_to_name?

  private

  def sync_jobs_for_search
    return unless Rails.configuration.x.opensearch_sync

    jobs.find_each { |job| JobSearchIndex.sync(job) }
  end
end
