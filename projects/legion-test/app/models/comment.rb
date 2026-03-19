class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user

  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete
    update!(deleted_at: Time.current)
  end

  def restore
    update!(deleted_at: nil)
  end
end