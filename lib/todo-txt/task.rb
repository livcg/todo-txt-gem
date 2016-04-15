require 'date'

module Todo
  # Creates a new task. The argument that you pass in must be the string
  # representation of a task.
  #
  # Example:
  #
  #   task = Todo::Task.new("(A) A high priority task!")
  class Task
    include Comparable
    include Todo::Logger
    include Todo::Syntax

    def initialize task
      @orig = task
      @priority = extract_priority(orig)
      @created_on = extract_created_on(orig)
      @due_on = extract_due_on_date(orig)
      @contexts ||= extract_contexts(orig)
      @projects ||= extract_projects(orig)

      if Todo.options.require_completed_on
        @completed_on = extract_completed_date(orig)
        @is_completed = !@completed_on.nil?
      else
        @completed_on = extract_completed_date(orig)
        @is_completed = check_completed_flag(orig)
      end
    end

    # Returns the original content of the task.
    #
    # Example:
    #
    #   task = Todo::Task.new "(A) @context +project Hello!"
    #   task.orig #=> "(A) @context +project Hello!"
    attr_reader :orig

    # Returns the task's creation date, if any.
    #
    # Example:
    #
    #   task = Todo::Task.new "(A) 2012-03-04 Task."
    #   task.created_on
    #   #=> <Date: 2012-03-04 (4911981/2,0,2299161)>
    #
    # Dates _must_ be in the YYYY-MM-DD format as specified in the todo.txt
    # format. Dates in any other format will be classed as malformed and this
    # attribute will be nil.
    attr_reader :created_on

    # Returns the task's completion date if task is done.
    #
    # Example:
    #
    #   task = Todo::Task.new "x 2012-03-04 Task."
    #   task.completed_on
    #   #=> <Date: 2012-03-04 (4911981/2,0,2299161)>
    #
    # Dates _must_ be in the YYYY-MM-DD format as specified in the todo.txt
    # format. Dates in any other format will be classed as malformed and this
    # attribute will be nil.
    attr_reader :completed_on

    # Returns the task's due date, if any.
    #
    # Example:
    #
    #   task = Todo::Task.new "(A) This is a task. due:2012-03-04"
    #   task.due_on
    #   #=> <Date: 2012-03-04 (4911981/2,0,2299161)>
    #
    # Dates _must_ be in the YYYY-MM-DD format as specified in the todo.txt
    # format. Dates in any other format will be classed as malformed and this
    # attribute will be nil.
    attr_reader :due_on

    # Returns the priority, if any.
    #
    # Example:
    #
    #   task = Todo::Task.new "(A) Some task."
    #   task.priority #=> "A"
    #
    #   task = Todo::Task.new "Some task."
    #   task.priority #=> nil
    attr_reader :priority

    # Returns an array of all the @context annotations.
    #
    # Example:
    #
    #   task = Todo:Task.new "(A) @context Testing!"
    #   task.context #=> ["@context"]
    attr_reader :contexts

    # Returns an array of all the +project annotations.
    #
    # Example:
    #
    #   task = Todo:Task.new "(A) +test Testing!"
    #   task.projects #=> ["+test"]
    attr_reader :projects

    # Gets just the text content of the todo, without the priority, contexts
    # and projects annotations.
    #
    # Example:
    #
    #   task = Todo::Task.new "(A) @test Testing!"
    #   task.text #=> "Testing!"
    def text
      @text ||= extract_item_text(orig)
    end

    # Returns the task's creation date, if any.
    #
    # Example:
    #
    #   task = Todo::Task.new "(A) 2012-03-04 Task."
    #   task.date
    #   #=> <Date: 2012-03-04 (4911981/2,0,2299161)>
    #
    # Dates _must_ be in the YYYY-MM-DD format as specified in the todo.txt
    # format. Dates in any other format will be classed as malformed and this
    # method will return nil.
    #
    # Deprecated
    def date
      logger.warn("Task#date is deprecated, use created_on instead.")

      @created_on
    end

    # Returns whether a task's due date is in the past.
    #
    # Example:
    #
    #   task = Todo::Task.new("This task is overdue! due:#{Date.today - 1}")
    #   task.overdue?
    #   #=> true
    def overdue?
      !due_on.nil? && due_on < Date.today
    end

    # Returns if the task is done.
    #
    # Example:
    #
    #   task = Todo::Task.new "x 2012-12-08 Task."
    #   task.done?
    #   #=> true
    #
    #   task = Todo::Task.new "Task."
    #   task.done?
    #   #=> false
    def done?
      @is_completed
    end

    # Completes the task on the current date.
    #
    # Example:
    #
    #   task = Todo::Task.new "2012-12-08 Task."
    #   task.done?
    #   #=> false
    #
    #   task.do!
    #   task.done?
    #   #=> true
    #   task.created_on
    #   #=> <Date: 2012-12-08 (4911981/2,0,2299161)>
    #   task.completed_on
    #   #=> # the current date
    def do!
      @completed_on = Date.today
      @is_completed = true
      @priority = nil
    end

    # Marks the task as incomplete and resets its original priority.
    #
    # Example:
    #
    #   task = Todo::Task.new "x 2012-12-08 2012-03-04 Task."
    #   task.done?
    #   #=> true
    #
    #   task.undo!
    #   task.done?
    #   #=> false
    #   task.created_on
    #   #=> <Date: 2012-03-04 (4911981/2,0,2299161)>
    #   task.completed_on
    #   #=> nil
    def undo!
      @completed_on = nil
      @is_completed = false
      @priority = extract_priority(orig)
    end

    # Increases the priority until A. If it's nil, it sets it to A.
    # @return [Char] the new priority of the task
    def priority_inc!
      if @priority.nil?
        @priority = 'A'
      elsif @priority.ord > 65
        @priority = (@priority.ord - 1).chr
      end
      @priority
    end

    # Decreases the priority until Z. if it's nil, it does nothing and
    # returns nil.
    # @return [Char] the new priority of the task
    def priority_dec!
      return if @priority.nil?
      @priority = @priority.next if @priority.ord < 90
      @priority
    end

    # Toggles the task from complete to incomplete or vice versa.
    #
    # Example:
    #
    #   task = Todo::Task.new "x 2012-12-08 Task."
    #   task.done?
    #   #=> true
    #
    #   task.toggle!
    #   task.done?
    #   #=> false
    #
    #   task.toggle!
    #   task.done?
    #   #=> true
    def toggle!
      done? ? undo! : do!
    end

    # Returns this task as a string.
    #
    # Example:
    #
    #   task = Todo::Task.new "(A) 2012-12-08 Task"
    #   task.to_s
    #   #=> "(A) 2012-12-08 Task"
    def to_s
      priority_string = priority ? "(#{priority}) " : ""
      done_string = done? ? "x #{completed_on} " : ""
      created_on_string = created_on ? "#{created_on} " : ""
      contexts_string = contexts.empty? ? "" : " #{contexts.join ' '}"
      projects_string = projects.empty? ? "" : " #{projects.join ' '}"
      due_on_string = due_on.nil? ? "" : " due:#{due_on}"
      "#{done_string}#{priority_string}#{created_on_string}#{text}#{contexts_string}#{projects_string}#{due_on_string}"
    end

    # Compares the priorities of two tasks.
    #
    # Example:
    #
    #   task1 = Todo::Task.new "(A) Priority A."
    #   task2 = Todo::Task.new "(B) Priority B."
    #
    #   task1 > task2
    #   # => true
    #
    #   task1 == task2
    #   # => false
    #
    #   task2 > task1
    #   # => false
    def <=> other_task
      if self.priority.nil? and other_task.priority.nil?
        0
      elsif other_task.priority.nil?
        1
      elsif self.priority.nil?
        -1
      else
        other_task.priority <=> self.priority
      end
    end
  end
end
