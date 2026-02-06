class RkkKintai < ActiveRecord::Base
  self.table_name = 'rkk_kintai'

  belongs_to :user

  validates :work_date, presence: true
  validates :start_time, :end_time, presence: true, unless: :attendance_time_optional?
  validate :end_after_start

  private

  def end_after_start
    return if attendance_time_optional?
    return if start_time.blank? || end_time.blank?

    if end_time <= start_time
      errors.add(:end_time, 'must be after start_time')
    end
  end

  def attendance_time_optional?
    %w[休暇 忌引 不就業 傷病].include?(work_attribute)
  end
end
