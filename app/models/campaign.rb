class Campaign < ApplicationRecord
  validates :source, presence: true
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :tracking_number, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }
  scope :random, -> { order(Arel.sql("RANDOM()")) }
end
