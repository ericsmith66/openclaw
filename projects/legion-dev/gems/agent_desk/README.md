# AgentDesk

Ruby agent framework for AI assistants.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'agent_desk', path: '../gems/agent_desk'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install agent_desk
```

## Usage

```ruby
require 'agent_desk'

# Access tool constants
puts AgentDesk::POWER_TOOL_BASH  # => "bash"

# Build tool IDs
puts AgentDesk.tool_id('power', 'bash')  # => "power---bash"

# Use type constants
puts AgentDesk::ToolApprovalState::ALWAYS  # => "always"

# Use data classes
file = AgentDesk::ContextFile.new(path: 'example.rb')
puts file.path  # => "example.rb"
```

## Development

Run tests:

```bash
bundle exec rake test
```

Build the gem:

```bash
gem build agent_desk.gemspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ericsmith66/legion.

## License

This gem is available as open source under the terms of the MIT License.
