# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PathResolverTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("path_resolver")
  end

  def teardown
    FileUtils.remove_entry(@project_dir) if File.exist?(@project_dir)
  end

  def test_resolve_relative_path_within_project
    result = AgentDesk::Tools::PowerTools::PathResolver.resolve("foo/bar", project_dir: @project_dir)
    expected = File.join(@project_dir, "foo/bar")
    assert_equal expected, result
  end

  def test_resolve_absolute_path_within_project
    abs = File.join(@project_dir, "baz")
    result = AgentDesk::Tools::PowerTools::PathResolver.resolve(abs, project_dir: @project_dir)
    assert_equal abs, result
  end

  def test_resolve_path_with_dot_components
    result = AgentDesk::Tools::PowerTools::PathResolver.resolve("./foo/../bar", project_dir: @project_dir)
    expected = File.join(@project_dir, "bar")
    assert_equal expected, result
  end

  def test_resolve_path_with_traversal_outside_project_raises
    assert_raises(AgentDesk::PathTraversalError) do
      AgentDesk::Tools::PowerTools::PathResolver.resolve("../../../etc/passwd", project_dir: @project_dir)
    end
  end

  def test_resolve_path_with_traversal_via_absolute_outside_raises
    outside = File.join(Dir.tmpdir, "outside")
    assert_raises(AgentDesk::PathTraversalError) do
      AgentDesk::Tools::PowerTools::PathResolver.resolve(outside, project_dir: @project_dir)
    end
  end

  def test_resolve_symlink_within_project
    link_target = File.join(@project_dir, "target")
    File.write(link_target, "data")
    link = File.join(@project_dir, "link")
    File.symlink(link_target, link)
    result = AgentDesk::Tools::PowerTools::PathResolver.resolve("link", project_dir: @project_dir)
    assert_equal File.realpath(link_target), result
  end

  def test_resolve_symlink_escaping_project_raises
    outside = Dir.mktmpdir("outside")
    target = File.join(outside, "secret")
    File.write(target, "data")
    link = File.join(@project_dir, "link")
    File.symlink(target, link)
    assert_raises(AgentDesk::PathTraversalError) do
      AgentDesk::Tools::PowerTools::PathResolver.resolve("link", project_dir: @project_dir)
    end
  ensure
    FileUtils.remove_entry(outside) if outside && File.exist?(outside)
  end

  def test_resolve_nonexistent_path_within_project
    result = AgentDesk::Tools::PowerTools::PathResolver.resolve("nonexistent/deep", project_dir: @project_dir)
    expected = File.join(@project_dir, "nonexistent/deep")
    assert_equal expected, result
  end

  def test_resolve_path_with_spaces
    result = AgentDesk::Tools::PowerTools::PathResolver.resolve("  foo/bar  ", project_dir: @project_dir)
    expected = File.join(@project_dir, "foo/bar")
    assert_equal expected, result
  end

  def test_resolve_requires_absolute_project_dir
    assert_raises(ArgumentError) do
      AgentDesk::Tools::PowerTools::PathResolver.resolve("foo", project_dir: "relative/path")
    end
  end
end
