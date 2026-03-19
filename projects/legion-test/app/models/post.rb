class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, as: :commentable, dependent: :destroy

  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete
    transaction do
      update!(deleted_at: Time.current)
      comments.where(deleted_at: nil).update_all(deleted_at: Time.current, cascade_deleted: true)
    end
  end

  def restore
    transaction do
      update!(deleted_at: nil)
      comments.with_deleted.where(cascade_deleted: true).update_all(deleted_at: nil, cascade_deleted: false)
    end
  end
end