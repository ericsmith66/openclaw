# frozen_string_literal: true

class TaskDependency < ApplicationRecord
  belongs_to :task
  belongs_to :depends_on_task, class_name: "Task"

  validates :task_id, presence: true
  validates :depends_on_task_id, presence: true
  validates :depends_on_task_id, uniqueness: { scope: :task_id }
  validate :no_self_reference
  validate :no_cycles

  def depends_on_task_position
    depends_on_task.position
  end

  private

  def no_self_reference
    if task_id == depends_on_task_id
      errors.add(:depends_on_task_id, "cannot depend on itself")
    end
  end

  def no_cycles
    return unless depends_on_task_id && task_id

    visited = Set.new
    queue = [ depends_on_task_id ]

    while queue.any?
      current_id = queue.shift
      next if visited.include?(current_id)

      if current_id == task_id
        errors.add(:base, "would create a dependency cycle")
        return
      end

      visited << current_id
      # Follow dependencies of current task
      next_deps = TaskDependency.where(task_id: current_id).pluck(:depends_on_task_id)
      queue.concat(next_deps)
    end
  end
end
