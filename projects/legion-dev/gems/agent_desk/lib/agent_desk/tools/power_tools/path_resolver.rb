# frozen_string_literal: true

require "pathname"

module AgentDesk
  module Tools
    module PowerTools
      # Utility for safely resolving relative paths within a project directory.
      # Prevents path traversal attacks (e.g., `../../../etc/passwd`).
      class PathResolver
        # Resolves a relative or absolute path against the project directory.
        # Raises `AgentDesk::PathTraversalError` if the resolved path is outside the project directory.
        #
        # @param path [String] relative or absolute path
        # @param project_dir [String] absolute path to project directory
        # @return [String] resolved absolute path
        # @raise [AgentDesk::PathTraversalError] if path escapes project_dir
        def self.resolve(path, project_dir:)
          path = path.to_s.strip
          raise ArgumentError, "project_dir must be an absolute path" unless Pathname.new(project_dir).absolute?

          # Expand path relative to project_dir if it's relative
          expanded = if Pathname.new(path).absolute?
                       path
          else
                       File.expand_path(path, project_dir)
          end

          # Compute canonical path (follow symlinks) if the file/directory exists
          canonical = if File.exist?(expanded)
                        File.realpath(expanded)
          else
                        File.expand_path(expanded)
          end

          # Ensure canonical path is still within project_dir (after symlink resolution)
          project_dir_real = File.realpath(project_dir)
          # Walk up the canonical path components, checking each existing directory
          pathname = Pathname.new(canonical)
          ancestors = pathname.ascend.to_a
          # Also include project_dir_real as a boundary
          safe = false
          ancestors.each do |ancestor|
            next unless ancestor.exist?
            # If this ancestor exists, its realpath must be within project_dir_real
            ancestor_real = ancestor.realpath
            unless ancestor_real.to_s.start_with?(project_dir_real + File::SEPARATOR) || ancestor_real.to_s == project_dir_real
              raise PathTraversalError,
                    "Path '#{path}' resolves to '#{canonical}' which is outside project directory '#{project_dir}'"
            end
            safe = true
            break
          end
          # If no ancestor existed (deep non-existent path), fall back to prefix check on unresolved canonical
          unless safe
            unless canonical.start_with?(project_dir + File::SEPARATOR) || canonical == project_dir
              raise PathTraversalError,
                    "Path '#{path}' resolves to '#{canonical}' which is outside project directory '#{project_dir}'"
            end
          end

          canonical
        end
      end
    end
  end
end
