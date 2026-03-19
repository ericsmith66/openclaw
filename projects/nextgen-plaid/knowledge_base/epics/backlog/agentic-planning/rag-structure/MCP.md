# RubyMine MCP Dump

- Generated at: `2026-01-23T22:52:39Z`
- Connected URL: `http://127.0.0.1:64342/sse`

## initialize
```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": {
    "capabilities": {
      "tools": {
        "listChanged": true
      }
    },
    "protocolVersion": "2024-11-05",
    "serverInfo": {
      "name": "RubyMine MCP Server",
      "version": "2025.3.1.1"
    }
  }
}
```

## tools/list
```json
{
  "id": 2,
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "description": "Creates a new file at the specified path within the project directory and optionally populates it with text if provided.\nUse this tool to generate new files in your project structure.\nNote: Creates any necessary parent directories automatically",
        "inputSchema": {
          "properties": {
            "overwrite": {
              "description": "Whether to overwrite an existing file if exists. If false, an exception is thrown in case of a conflict.",
              "type": "boolean"
            },
            "pathInProject": {
              "description": "Path where the file should be created relative to the project root",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "text": {
              "description": "Content to write into the new file",
              "type": "string"
            }
          },
          "required": [
            "pathInProject"
          ],
          "type": "object"
        },
        "name": "create_new_file"
      },
      {
        "description": "Run a specific run configuration in the current project and wait up to specified timeout for it to finish.\nUse this tool to run a run configuration that you have found from the \"get_run_configurations\" tool.\nReturns the execution result including exit code, output, and success status.",
        "inputSchema": {
          "properties": {
            "configurationName": {
              "description": "Name of the run configuration to execute",
              "type": "string"
            },
            "maxLinesCount": {
              "description": "Maximum number of lines to return",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            },
            "truncateMode": {
              "description": "How to truncate the text: from the start, in the middle, at the end, or don't truncate at all",
              "enum": [
                "START",
                "MIDDLE",
                "END",
                "NONE"
              ]
            }
          },
          "required": [
            "configurationName"
          ],
          "type": "object"
        },
        "name": "execute_run_configuration",
        "outputSchema": {
          "properties": {
            "exitCode": {
              "type": [
                "integer",
                "null"
              ]
            },
            "output": {
              "type": "string"
            },
            "timedOut": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            }
          },
          "required": [
            "output"
          ],
          "type": "object"
        }
      },
      {
        "description": "        Executes a specified shell command in the IDE's integrated terminal.\n        Use this tool to run terminal commands within the IDE environment.\n        Requires a command parameter containing the shell command to execute.\n        Important features and limitations:\n        - Checks if process is running before collecting output\n        - Limits output to 2000 lines (truncates excess)\n        - Times out after specified timeout with notification\n        - Requires user confirmation unless \"Brave Mode\" is enabled in settings\n        Returns possible responses:\n        - Terminal output (truncated if > 2000 lines)\n        - Output with interruption notice if timed out\n        - Error messages for various failure cases",
        "inputSchema": {
          "properties": {
            "command": {
              "description": "Shell command to execute",
              "type": "string"
            },
            "executeInShell": {
              "description": "Whether to execute the command in a default user's shell (bash, zsh, etc.). \nUseful if the command is not a commandline but a shell script, or if it's important to preserve real environment of the user's terminal. \nIn the case of 'false' value the command will be started as a process",
              "type": "boolean"
            },
            "maxLinesCount": {
              "description": "Maximum number of lines to return",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "reuseExistingTerminalWindow": {
              "description": "Whether to reuse an existing terminal window. Allows to avoid creating multiple terminals",
              "type": "boolean"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            },
            "truncateMode": {
              "description": "How to truncate the text: from the start, in the middle, at the end, or don't truncate at all",
              "enum": [
                "START",
                "MIDDLE",
                "END",
                "NONE"
              ]
            }
          },
          "required": [
            "command"
          ],
          "type": "object"
        },
        "name": "execute_terminal_command",
        "outputSchema": {
          "properties": {
            "command_exit_code": {
              "type": [
                "integer",
                "null"
              ]
            },
            "command_output": {
              "type": "string"
            },
            "is_timed_out": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            }
          },
          "required": [
            "command_output"
          ],
          "type": "object"
        }
      },
      {
        "description": "Searches for all files in the project whose relative paths match the specified glob pattern.\nThe search is performed recursively in all subdirectories of the project directory or a specified subdirectory.\nUse this tool when you need to find files by a glob pattern (e.g. '**/*.txt').",
        "inputSchema": {
          "properties": {
            "addExcluded": {
              "description": "Whether to add excluded/ignored files to the search results. Files can be excluded from a project either by user of by some ignore rules",
              "type": "boolean"
            },
            "fileCountLimit": {
              "description": "Maximum number of files to return.",
              "type": "integer"
            },
            "globPattern": {
              "description": "Glob pattern to search for. The pattern must be relative to the project root. Example: `src/**/ *.java`",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "subDirectoryRelativePath": {
              "description": "Optional subdirectory relative to the project to search in.",
              "type": "string"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            }
          },
          "required": [
            "globPattern"
          ],
          "type": "object"
        },
        "name": "find_files_by_glob",
        "outputSchema": {
          "properties": {
            "files": {
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "probablyHasMoreMatchingFiles": {
              "type": "boolean"
            },
            "timedOut": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            }
          },
          "required": [
            "probablyHasMoreMatchingFiles",
            "files"
          ],
          "type": "object"
        }
      },
      {
        "description": "Searches for all files in the project whose names contain the specified keyword (case-insensitive).\nUse this tool to locate files when you know part of the filename.\nNote: Matched only names, not paths, because works via indexes.\nNote: Only searches through files within the project directory, excluding libraries and external dependencies.\nNote: Prefer this tool over other `find` tools because it's much faster, \nbut remember that this tool searches only names, not paths and it doesn't support glob patterns.",
        "inputSchema": {
          "properties": {
            "fileCountLimit": {
              "description": "Maximum number of files to return.",
              "type": "integer"
            },
            "nameKeyword": {
              "description": "Substring to search for in file names",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            }
          },
          "required": [
            "nameKeyword"
          ],
          "type": "object"
        },
        "name": "find_files_by_name_keyword",
        "outputSchema": {
          "properties": {
            "files": {
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "probablyHasMoreMatchingFiles": {
              "type": "boolean"
            },
            "timedOut": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            }
          },
          "required": [
            "probablyHasMoreMatchingFiles",
            "files"
          ],
          "type": "object"
        }
      },
      {
        "description": "Returns active editor's and other open editors' file paths relative to the project root.\n\nUse this tool to explore current open editors.",
        "inputSchema": {
          "properties": {
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [],
          "type": "object"
        },
        "name": "get_all_open_file_paths",
        "outputSchema": {
          "properties": {
            "activeFilePath": {
              "type": [
                "string",
                "null"
              ]
            },
            "openFiles": {
              "items": {
                "type": "string"
              },
              "type": "array"
            }
          },
          "required": [
            "openFiles"
          ],
          "type": "object"
        }
      },
      {
        "description": "Analyzes the specified file for errors and warnings using IntelliJ's inspections.\nUse this tool to identify coding issues, syntax errors, and other problems in a specific file.\nReturns a list of problems found in the file, including severity, description, and location information.\nNote: Only analyzes files within the project directory.\nNote: Lines and Columns are 1-based.",
        "inputSchema": {
          "properties": {
            "errorsOnly": {
              "description": "Whether to include only errors or include both errors and warnings",
              "type": "boolean"
            },
            "filePath": {
              "description": "Path relative to the project root",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            }
          },
          "required": [
            "filePath"
          ],
          "type": "object"
        },
        "name": "get_file_problems",
        "outputSchema": {
          "properties": {
            "errors": {
              "items": {
                "properties": {
                  "column": {
                    "type": "integer"
                  },
                  "description": {
                    "type": "string"
                  },
                  "line": {
                    "type": "integer"
                  },
                  "lineContent": {
                    "type": "string"
                  },
                  "severity": {
                    "type": "string"
                  }
                },
                "required": [
                  "severity",
                  "description",
                  "lineContent",
                  "line",
                  "column"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "filePath": {
              "type": "string"
            },
            "timedOut": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            }
          },
          "required": [
            "filePath",
            "errors"
          ],
          "type": "object"
        }
      },
      {
        "description": "        Retrieves the text content of a file using its path relative to project root.\n        Use this tool to read file contents when you have the file's project-relative path.\n        In the case of binary files, the tool returns an error.\n        If the file is too large, the text will be truncated with '<<<...content truncated...>>>' marker and in according to the `truncateMode` parameter.",
        "inputSchema": {
          "properties": {
            "maxLinesCount": {
              "description": "Max number of lines to return. Truncation will be performed depending on truncateMode.",
              "type": "integer"
            },
            "pathInProject": {
              "description": "Path relative to the project root",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "truncateMode": {
              "description": "How to truncate the text: from the start, in the middle, at the end, or don't truncate at all",
              "enum": [
                "START",
                "MIDDLE",
                "END",
                "NONE"
              ]
            }
          },
          "required": [
            "pathInProject"
          ],
          "type": "object"
        },
        "name": "get_file_text_by_path"
      },
      {
        "description": "Get a list of all dependencies defined in the project.\nReturns structured information about project library names.",
        "inputSchema": {
          "properties": {
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [],
          "type": "object"
        },
        "name": "get_project_dependencies",
        "outputSchema": {
          "properties": {
            "dependencies": {
              "items": {
                "properties": {
                  "name": {
                    "type": "string"
                  }
                },
                "required": [
                  "name"
                ],
                "type": "object"
              },
              "type": "array"
            }
          },
          "required": [
            "dependencies"
          ],
          "type": "object"
        }
      },
      {
        "description": "Get a list of all modules in the project with their types.\nReturns structured information about each module including name and type.",
        "inputSchema": {
          "properties": {
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [],
          "type": "object"
        },
        "name": "get_project_modules",
        "outputSchema": {
          "properties": {
            "modules": {
              "items": {
                "properties": {
                  "name": {
                    "type": "string"
                  },
                  "type": {
                    "type": [
                      "string",
                      "null"
                    ]
                  }
                },
                "required": [
                  "name"
                ],
                "type": "object"
              },
              "type": "array"
            }
          },
          "required": [
            "modules"
          ],
          "type": "object"
        }
      },
      {
        "description": "Use this tool to retrieve information about the available Rails controllers. Because the application can contain many controllers, \nthe results are returned in a paginated list sorted by the FQN of the controllers.\n\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\n\nCommon usage patterns:\n   - Find all controllers located in the top level Admin namespace: included_fqn_filters=['^Admin::']\n   - Find all controllers that are in the global namespace: excluded_fqn_filters=['.+::']\n   - Find controllers that are not abstract: abstract_filter=NON_ABSTRACT_ONLY\n   - Which controllers have no partial views: excluded_view_filters=[HAS_PARTIAL_VIEW]",
        "inputSchema": {
          "properties": {
            "abstract_filter": {
              "description": "Filter entries based on whether they are abstract.\n\nOptions:\n - ABSTRACT_ONLY: Return only abstract entries\n - NON_ABSTRACT_ONLY: Return only non-abstract entries\n - ANY: Return all entries regardless of whether they are abstract (no filtering applied)\n\nDefault: ANY",
              "enum": [
                "ANY",
                "ABSTRACT_ONLY",
                "NON_ABSTRACT_ONLY"
              ]
            },
            "excluded_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_view_filters": {
              "description": "Filter controllers based on their associated views. Returns only controllers that do NOT have any views matched by ANY of these \nfilters (OR logic). A view filter is defined as follows: '\nFilter entries based on whether they have a corresponding Rails view file.\n\nOptions:\n - HAS_ANY_VIEW: Return only entries that have a corresponding view file (e.g., index.html.erb, _upload.json.jbuilder)\n - HAS_PARTIAL_VIEW: Return only entries that have a corresponding partial view file (e.g., _form.html.erb, _list.json.jbuilder)\n - HAS_NON_PARTIAL_VIEW: Return only entries that have a corresponding non-partial view file (e.g., index.html.erb, show.json.jbuilder)\n - HAS_LAYOUTS: Return only entries that have a corresponding layout file\n - HAS_NO_VIEW: Return only entries that do NOT have a corresponding view file\n    '.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "enum": [
                  "HAS_ANY_VIEW",
                  "HAS_LAYOUTS",
                  "HAS_PARTIAL_VIEW",
                  "HAS_NON_PARTIAL_VIEW",
                  "HAS_NO_VIEW"
                ]
              },
              "type": "array"
            },
            "included_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Include namespace: '^Test::' includes anything starting with Test::\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\n  - Include suffix: 'Internal$' includes classes ending with Internal\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_view_filters": {
              "description": "Filter controllers based on their associated views. Returns controllers that have at least one view matching ANY of these filters (OR logic).\nA view filter is defined as follows: '\nFilter entries based on whether they have a corresponding Rails view file.\n\nOptions:\n - HAS_ANY_VIEW: Return only entries that have a corresponding view file (e.g., index.html.erb, _upload.json.jbuilder)\n - HAS_PARTIAL_VIEW: Return only entries that have a corresponding partial view file (e.g., _form.html.erb, _list.json.jbuilder)\n - HAS_NON_PARTIAL_VIEW: Return only entries that have a corresponding non-partial view file (e.g., index.html.erb, show.json.jbuilder)\n - HAS_LAYOUTS: Return only entries that have a corresponding layout file\n - HAS_NO_VIEW: Return only entries that do NOT have a corresponding view file\n    '.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "enum": [
                  "HAS_ANY_VIEW",
                  "HAS_LAYOUTS",
                  "HAS_PARTIAL_VIEW",
                  "HAS_NON_PARTIAL_VIEW",
                  "HAS_NO_VIEW"
                ]
              },
              "type": "array"
            },
            "model_filter": {
              "description": "Filter entries based on whether they have a corresponding Rails model.\n\nOptions:\n - WITH_MODEL_ONLY: Include only entries that have an associated Rails model\n - WITHOUT_MODEL_ONLY: Include only entries that have no associated Rails model\n - ANY: Include all entries, regardless of model association (no filtering is performed)\n\nDefault: ANY",
              "enum": [
                "ANY",
                "WITH_MODEL_ONLY",
                "WITHOUT_MODEL_ONLY"
              ]
            },
            "page": {
              "description": "The number of the page to retrieve, indexed from 1.",
              "type": "integer"
            },
            "page_size": {
              "description": "The maximum number of items to return per page.",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "page",
            "page_size"
          ],
          "type": "object"
        },
        "name": "get_rails_controllers",
        "outputSchema": {
          "properties": {
            "items": {
              "description": "The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.",
              "items": {
                "properties": {
                  "controller": {
                    "description": "Symbol information for the Rails controller class, including its fully qualified name and location in source code.",
                    "properties": {
                      "column": {
                        "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      },
                      "filePath": {
                        "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "string"
                      },
                      "fqn": {
                        "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                        "type": "string"
                      },
                      "line": {
                        "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      }
                    },
                    "required": [
                      "fqn",
                      "filePath",
                      "line",
                      "column"
                    ],
                    "type": "object"
                  },
                  "isAbstract": {
                    "description": "true if the controller is abstract; otherwise false",
                    "type": "boolean"
                  },
                  "managedLayouts": {
                    "description": "Absolute filesystem paths of layout files that this controller renders.",
                    "items": {
                      "type": "string"
                    },
                    "type": "array"
                  },
                  "managedPartialViews": {
                    "description": "Absolute filesystem paths of partial view files (e.g., _form.html.erb, _user.html.erb) that are scoped to this controller and can be rendered from its views or actions.",
                    "items": {
                      "type": "string"
                    },
                    "type": "array"
                  },
                  "managedViews": {
                    "description": "Absolute filesystem paths of non-partial view files (e.g., index.html.erb, show.json.jbuilder) that this controller renders.",
                    "items": {
                      "type": "string"
                    },
                    "type": "array"
                  },
                  "model": {
                    "description": "Symbol information for the Rails model that this controller corresponds to. Null if no such model could be determined.",
                    "properties": {
                      "column": {
                        "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      },
                      "filePath": {
                        "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "string"
                      },
                      "fqn": {
                        "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                        "type": "string"
                      },
                      "line": {
                        "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      }
                    },
                    "required": [
                      "fqn",
                      "filePath",
                      "line",
                      "column"
                    ],
                    "type": [
                      "object",
                      "null"
                    ]
                  }
                },
                "required": [
                  "controller",
                  "isAbstract",
                  "managedViews",
                  "managedPartialViews",
                  "managedLayouts"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "summary": {
              "description": "Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.",
              "properties": {
                "cacheKey": {
                  "description": "The cache key of the last update.",
                  "type": "string"
                },
                "item_count": {
                  "description": "The actual number of items returned on this page.",
                  "type": "integer"
                },
                "page": {
                  "description": "The number of the current page, indexed from 1.",
                  "type": "integer"
                },
                "total_items": {
                  "description": "The total number of items in the collection.",
                  "type": "integer"
                },
                "total_pages": {
                  "description": "The total number of pages available in the entire collection with the requested page size.",
                  "type": "integer"
                }
              },
              "required": [
                "page",
                "item_count",
                "total_pages",
                "total_items",
                "cacheKey"
              ],
              "type": "object"
            }
          },
          "required": [
            "summary",
            "items"
          ],
          "type": "object"
        }
      },
      {
        "description": "Use this tool to retrieve information about the available Rails helpers. Because the application can contain many helpers, \nthe results are returned in a paginated list sorted by the FQN (Fully Qualified Name) of the helpers.\n\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\n\nCommon usage patterns:\n   - Which helpers are located in some kind of utility namespace: included_fqn_filters=['(::)?utility.*::']\n   - Find helpers outside the CI directory: excluded_directory_filters=['/CI/']",
        "inputSchema": {
          "properties": {
            "excluded_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Include namespace: '^Test::' includes anything starting with Test::\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\n  - Include suffix: 'Internal$' includes classes ending with Internal\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "page": {
              "description": "The number of the page to retrieve, indexed from 1.",
              "type": "integer"
            },
            "page_size": {
              "description": "The maximum number of items to return per page.",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "page",
            "page_size"
          ],
          "type": "object"
        },
        "name": "get_rails_helpers",
        "outputSchema": {
          "properties": {
            "items": {
              "description": "The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.",
              "items": {
                "properties": {
                  "column": {
                    "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                    "type": "integer"
                  },
                  "filePath": {
                    "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                    "type": "string"
                  },
                  "fqn": {
                    "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                    "type": "string"
                  },
                  "line": {
                    "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                    "type": "integer"
                  }
                },
                "required": [
                  "fqn",
                  "filePath",
                  "line",
                  "column"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "summary": {
              "description": "Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.",
              "properties": {
                "cacheKey": {
                  "description": "The cache key of the last update.",
                  "type": "string"
                },
                "item_count": {
                  "description": "The actual number of items returned on this page.",
                  "type": "integer"
                },
                "page": {
                  "description": "The number of the current page, indexed from 1.",
                  "type": "integer"
                },
                "total_items": {
                  "description": "The total number of items in the collection.",
                  "type": "integer"
                },
                "total_pages": {
                  "description": "The total number of pages available in the entire collection with the requested page size.",
                  "type": "integer"
                }
              },
              "required": [
                "page",
                "item_count",
                "total_pages",
                "total_items",
                "cacheKey"
              ],
              "type": "object"
            }
          },
          "required": [
            "summary",
            "items"
          ],
          "type": "object"
        }
      },
      {
        "description": "Use this tool to retrieve information about the available Rails mailers. Because the application can contain many mailers, \nthe results are returned in a paginated list sorted by the FQN of the mailers.\n\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.",
        "inputSchema": {
          "properties": {
            "excluded_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Include namespace: '^Test::' includes anything starting with Test::\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\n  - Include suffix: 'Internal$' includes classes ending with Internal\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "page": {
              "description": "The number of the page to retrieve, indexed from 1.",
              "type": "integer"
            },
            "page_size": {
              "description": "The maximum number of items to return per page.",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "page",
            "page_size"
          ],
          "type": "object"
        },
        "name": "get_rails_mailers",
        "outputSchema": {
          "properties": {
            "items": {
              "description": "The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.",
              "items": {
                "properties": {
                  "column": {
                    "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                    "type": "integer"
                  },
                  "filePath": {
                    "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                    "type": "string"
                  },
                  "fqn": {
                    "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                    "type": "string"
                  },
                  "line": {
                    "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                    "type": "integer"
                  }
                },
                "required": [
                  "fqn",
                  "filePath",
                  "line",
                  "column"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "summary": {
              "description": "Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.",
              "properties": {
                "cacheKey": {
                  "description": "The cache key of the last update.",
                  "type": "string"
                },
                "item_count": {
                  "description": "The actual number of items returned on this page.",
                  "type": "integer"
                },
                "page": {
                  "description": "The number of the current page, indexed from 1.",
                  "type": "integer"
                },
                "total_items": {
                  "description": "The total number of items in the collection.",
                  "type": "integer"
                },
                "total_pages": {
                  "description": "The total number of pages available in the entire collection with the requested page size.",
                  "type": "integer"
                }
              },
              "required": [
                "page",
                "item_count",
                "total_pages",
                "total_items",
                "cacheKey"
              ],
              "type": "object"
            }
          },
          "required": [
            "summary",
            "items"
          ],
          "type": "object"
        }
      },
      {
        "description": "Use this tool to retrieve information about the available Rails models. Because the application can contain many models, the results\nare returned in a paginated list sorted by the FQN of the models.\n\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\n    \nCommon usage patterns:\n   - Find all models located in any CI namespace: included_fqn_filters=['(::)?CI::']\n   - Find all models in the admin directory: included_directory_filters=['admin']\n   - Find models that have a corresponding controller: controller_filter=WITH_CONTROLLER_ONLY",
        "inputSchema": {
          "properties": {
            "controller_filter": {
              "description": "Filter entries based on whether they have a corresponding Rails controller.\n\nOptions:\n - WITH_CONTROLLER_ONLY: Return only entries that have a corresponding controller\n - WITHOUT_MODEL_ONLY: Return only entries that do NOT have a corresponding controller\n - ANY: Return all entries regardless of whether they have a corresponding controller (no filtering applied)\n\nDefault: ANY",
              "enum": [
                "ANY",
                "WITH_CONTROLLER_ONLY",
                "WITHOUT_CONTROLLER_ONLY"
              ]
            },
            "excluded_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Include namespace: '^Test::' includes anything starting with Test::\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\n  - Include suffix: 'Internal$' includes classes ending with Internal\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "page": {
              "description": "The number of the page to retrieve, indexed from 1.",
              "type": "integer"
            },
            "page_size": {
              "description": "The maximum number of items to return per page.",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "page",
            "page_size"
          ],
          "type": "object"
        },
        "name": "get_rails_models",
        "outputSchema": {
          "properties": {
            "items": {
              "description": "The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.",
              "items": {
                "properties": {
                  "controller": {
                    "description": "The Rails controller corresponding to this model. Null if no corresponding controller exists.",
                    "properties": {
                      "column": {
                        "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      },
                      "filePath": {
                        "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "string"
                      },
                      "fqn": {
                        "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                        "type": "string"
                      },
                      "line": {
                        "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      }
                    },
                    "required": [
                      "fqn",
                      "filePath",
                      "line",
                      "column"
                    ],
                    "type": [
                      "object",
                      "null"
                    ]
                  },
                  "model": {
                    "description": "The Rails model. Contains symbol information including FQN, file path, and location.",
                    "properties": {
                      "column": {
                        "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      },
                      "filePath": {
                        "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "string"
                      },
                      "fqn": {
                        "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                        "type": "string"
                      },
                      "line": {
                        "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      }
                    },
                    "required": [
                      "fqn",
                      "filePath",
                      "line",
                      "column"
                    ],
                    "type": "object"
                  }
                },
                "required": [
                  "model"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "summary": {
              "description": "Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.",
              "properties": {
                "cacheKey": {
                  "description": "The cache key of the last update.",
                  "type": "string"
                },
                "item_count": {
                  "description": "The actual number of items returned on this page.",
                  "type": "integer"
                },
                "page": {
                  "description": "The number of the current page, indexed from 1.",
                  "type": "integer"
                },
                "total_items": {
                  "description": "The total number of items in the collection.",
                  "type": "integer"
                },
                "total_pages": {
                  "description": "The total number of pages available in the entire collection with the requested page size.",
                  "type": "integer"
                }
              },
              "required": [
                "page",
                "item_count",
                "total_pages",
                "total_items",
                "cacheKey"
              ],
              "type": "object"
            }
          },
          "required": [
            "summary",
            "items"
          ],
          "type": "object"
        }
      },
      {
        "description": "Use this tool to retrieve information about available Rails routes in the application. Because the application can contain many routes, the results\nare returned in a paginated list sorted by route path pattern.\n\nPrefer this tool over searching the codebase (e.g., routes.rb files), as it performs a more in-depth analysis and returns more accurate, runtime-aware data.\n\nCommon usage patterns:\n   - Find all API routes: included_route_path_filters=['api']\n   - Find routes that are handled by the create method: included_action_name_filters=['create']\n   - Find routes that are handled by the ReleasesController: included_action_namespace_filters=['ReleasesController']\n   - Find routes with at least 2 actions: min_action_count=2\n   - Find routes that don't handle DELETE requests: excluded_http_method_filters=['DELETE']",
        "inputSchema": {
          "properties": {
            "excluded_action_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_action_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_http_method_filters": {
              "description": "Filter objects by corresponding HTTP methods. Only objects that do NOT respond to any of these HTTP methods will be returned. \nExample: [GET, POST] would return objects that do NOT handle GET or POST requests. \n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "enum": [
                  "GET",
                  "HEAD",
                  "POST",
                  "PUT",
                  "DELETE",
                  "CONNECT",
                  "OPTIONS",
                  "TRACE",
                  "PATCH"
                ]
              },
              "type": "array"
            },
            "excluded_route_path_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_action_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_action_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Include namespace: '^Test::' includes anything starting with Test::\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\n  - Include suffix: 'Internal$' includes classes ending with Internal\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_http_method_filters": {
              "description": "Filter objects by corresponding HTTP methods. Only objects that respond to at least one of these HTTP methods will be returned. \nExample: [GET, POST] would return objects that handle GET or POST requests. \n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "enum": [
                  "GET",
                  "HEAD",
                  "POST",
                  "PUT",
                  "DELETE",
                  "CONNECT",
                  "OPTIONS",
                  "TRACE",
                  "PATCH"
                ]
              },
              "type": "array"
            },
            "included_route_path_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "max_action_count": {
              "description": "Maximum number of distinct controller actions a route can map to (inclusive). \nA single route path may map to multiple actions via different HTTP methods. \nSet this to filter out routes with too many actions. \n\nDefault: 4294967295 (no maximum)",
              "type": "integer"
            },
            "min_action_count": {
              "description": "Minimum number of distinct controller actions a route must map to (inclusive). \nA single route path may map to multiple actions via different HTTP methods.\nFor example, '/users/:id' might have GET (show), PUT (update), and DELETE (destroy) actions. \n\nDefault: 0 (no minimum)",
              "type": "integer"
            },
            "page": {
              "description": "The number of the page to retrieve, indexed from 1.",
              "type": "integer"
            },
            "page_size": {
              "description": "The maximum number of items to return per page.",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "page",
            "page_size"
          ],
          "type": "object"
        },
        "name": "get_rails_routes",
        "outputSchema": {
          "properties": {
            "items": {
              "description": "The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.",
              "items": {
                "properties": {
                  "actions": {
                    "description": "List of controller actions mapped to this route. Multiple actions can exist for different HTTP methods. An empty list indicates that no matching controller actions were found in the codebase.",
                    "items": {
                      "properties": {
                        "handler": {
                          "description": "The Ruby method that handles this route action. Contains information about the controller method including its name, location, and namespace.",
                          "properties": {
                            "column": {
                              "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                              "type": "integer"
                            },
                            "filePath": {
                              "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                              "type": "string"
                            },
                            "fqn": {
                              "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                              "type": "string"
                            },
                            "line": {
                              "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                              "type": "integer"
                            }
                          },
                          "required": [
                            "fqn",
                            "filePath",
                            "line",
                            "column"
                          ],
                          "type": "object"
                        },
                        "httpMethod": {
                          "description": "The HTTP method (GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH) that this action handles. Returns null if the HTTP method could not be determined.",
                          "enum": [
                            "GET",
                            "HEAD",
                            "POST",
                            "PUT",
                            "DELETE",
                            "CONNECT",
                            "OPTIONS",
                            "TRACE",
                            "PATCH"
                          ]
                        }
                      },
                      "required": [
                        "handler"
                      ],
                      "type": "object"
                    },
                    "type": "array"
                  },
                  "path": {
                    "description": "The Rails route path pattern using Rails conventions (e.g., '/users/:id/edit', '/api/v1/posts').",
                    "type": "string"
                  }
                },
                "required": [
                  "path",
                  "actions"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "summary": {
              "description": "Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.",
              "properties": {
                "cacheKey": {
                  "description": "The cache key of the last update.",
                  "type": "string"
                },
                "item_count": {
                  "description": "The actual number of items returned on this page.",
                  "type": "integer"
                },
                "page": {
                  "description": "The number of the current page, indexed from 1.",
                  "type": "integer"
                },
                "total_items": {
                  "description": "The total number of items in the collection.",
                  "type": "integer"
                },
                "total_pages": {
                  "description": "The total number of pages available in the entire collection with the requested page size.",
                  "type": "integer"
                }
              },
              "required": [
                "page",
                "item_count",
                "total_pages",
                "total_items",
                "cacheKey"
              ],
              "type": "object"
            }
          },
          "required": [
            "summary",
            "items"
          ],
          "type": "object"
        }
      },
      {
        "description": "Use this tool to retrieve information about the available Rails views. Because the application can contain many views, \nthe results are returned in a paginated list sorted by the path of the views.\n\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\n\nCommon usage patterns:\n   - Find non-HAML views in the project: excluded_path_filters=['.haml']\n   - Find views that correspond to the GroupsController: included_controller_fqn_filters=['GroupsController']",
        "inputSchema": {
          "properties": {
            "controller_filter": {
              "description": "Filter entries based on whether they have a corresponding Rails controller.\n\nOptions:\n - WITH_CONTROLLER_ONLY: Return only entries that have a corresponding controller\n - WITHOUT_MODEL_ONLY: Return only entries that do NOT have a corresponding controller\n - ANY: Return all entries regardless of whether they have a corresponding controller (no filtering applied)\n\nDefault: ANY",
              "enum": [
                "ANY",
                "WITH_CONTROLLER_ONLY",
                "WITHOUT_CONTROLLER_ONLY"
              ]
            },
            "excluded_controller_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_controller_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "excluded_path_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_controller_directory_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_controller_fqn_filters": {
              "description": "Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\n\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\n\nCOMMON PATTERNS:\n  - Include namespace: '^Test::' includes anything starting with Test::\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\n  - Include suffix: 'Internal$' includes classes ending with Internal\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "included_path_filters": {
              "description": "Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\nInvalid patterns are ignored. \n\nCOMMON PATTERNS:\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\n  - Include file extension: [\".rb\", \".erb\"] includes all Ruby and ERB files.\n\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.",
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "layout_filter": {
              "description": "Filter views based on whether they are layouts.\n\nOptions:\n - LAYOUT_ONLY: Return only views that are also layouts\n - NON_LAYOUT_ONLY: Return only views that are NOT layouts\n - ANY: Return all views regardless of whether they are layouts (no filtering applied)\n\nDefault: ANY",
              "enum": [
                "ANY",
                "LAYOUT_ONLY",
                "NON_LAYOUT_ONLY"
              ]
            },
            "page": {
              "description": "The number of the page to retrieve, indexed from 1.",
              "type": "integer"
            },
            "page_size": {
              "description": "The maximum number of items to return per page.",
              "type": "integer"
            },
            "partiality_filter": {
              "description": "Filter entries based on whether they are partial.\n\nOptions:\n - PARTIAL_ONLY: Return only partial entries\n - NON_PARTIAL_ONLY: Return only non-partial entries\n - ANY: Return all entries regardless of whether they are partial (no filtering applied)\n\nDefault: ANY",
              "enum": [
                "ANY",
                "PARTIAL_ONLY",
                "NON_PARTIAL_ONLY"
              ]
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "page",
            "page_size"
          ],
          "type": "object"
        },
        "name": "get_rails_views",
        "outputSchema": {
          "properties": {
            "items": {
              "description": "The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.",
              "items": {
                "properties": {
                  "absolutePath": {
                    "description": "Absolute filesystem path to the view file (e.g., '/home/user/project/app/views/users/index.html.erb')",
                    "type": "string"
                  },
                  "controller": {
                    "description": "Symbol information for the controller associated with this view (includes FQN, file path, and location), or null if no corresponding controller exists.",
                    "properties": {
                      "column": {
                        "description": "1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      },
                      "filePath": {
                        "description": "The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "string"
                      },
                      "fqn": {
                        "description": "The fully qualified name (FQN) of the symbol. Can be used to query symbol details.",
                        "type": "string"
                      },
                      "line": {
                        "description": "1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.",
                        "type": "integer"
                      }
                    },
                    "required": [
                      "fqn",
                      "filePath",
                      "line",
                      "column"
                    ],
                    "type": [
                      "object",
                      "null"
                    ]
                  },
                  "isLayout": {
                    "description": "true if this view is a layout; false otherwise",
                    "type": "boolean"
                  },
                  "isPartial": {
                    "description": "true if this is a partial view; false otherwise",
                    "type": "boolean"
                  }
                },
                "required": [
                  "absolutePath",
                  "isPartial",
                  "isLayout"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "summary": {
              "description": "Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.",
              "properties": {
                "cacheKey": {
                  "description": "The cache key of the last update.",
                  "type": "string"
                },
                "item_count": {
                  "description": "The actual number of items returned on this page.",
                  "type": "integer"
                },
                "page": {
                  "description": "The number of the current page, indexed from 1.",
                  "type": "integer"
                },
                "total_items": {
                  "description": "The total number of items in the collection.",
                  "type": "integer"
                },
                "total_pages": {
                  "description": "The total number of pages available in the entire collection with the requested page size.",
                  "type": "integer"
                }
              },
              "required": [
                "page",
                "item_count",
                "total_pages",
                "total_items",
                "cacheKey"
              ],
              "type": "object"
            }
          },
          "required": [
            "summary",
            "items"
          ],
          "type": "object"
        }
      },
      {
        "description": "Retrieves the list of VCS roots in the project.\nThis is useful to detect all repositories in a multi-repository project.",
        "inputSchema": {
          "properties": {
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [],
          "type": "object"
        },
        "name": "get_repositories",
        "outputSchema": {
          "properties": {
            "roots": {
              "items": {
                "properties": {
                  "pathRelativeToProject": {
                    "description": "Path of repository relative to the project directory. Empty string means the project root",
                    "type": "string"
                  },
                  "vcsName": {
                    "description": "VCS used by this repository",
                    "type": "string"
                  }
                },
                "required": [
                  "pathRelativeToProject",
                  "vcsName"
                ],
                "type": "object"
              },
              "type": "array"
            }
          },
          "required": [
            "roots"
          ],
          "type": "object"
        }
      },
      {
        "description": "Returns a list of run configurations for the current project.\nRun configurations are usually used to define user the way how to run a user application, task or test suite from sources.\n\nThis tool provides additional info like command line, working directory, and environment variables if they are available.\n\nUse this tool to query the list of available run configurations in the current project.",
        "inputSchema": {
          "properties": {
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [],
          "type": "object"
        },
        "name": "get_run_configurations",
        "outputSchema": {
          "properties": {
            "configurations": {
              "items": {
                "properties": {
                  "commandLine": {
                    "type": [
                      "string",
                      "null"
                    ]
                  },
                  "description": {
                    "type": [
                      "string",
                      "null"
                    ]
                  },
                  "environment": {
                    "additionalProperties": {
                      "type": "string"
                    },
                    "type": [
                      "object",
                      "null"
                    ]
                  },
                  "name": {
                    "type": "string"
                  },
                  "workingDirectory": {
                    "type": [
                      "string",
                      "null"
                    ]
                  }
                },
                "required": [
                  "name"
                ],
                "type": "object"
              },
              "type": "array"
            }
          },
          "required": [
            "configurations"
          ],
          "type": "object"
        }
      },
      {
        "description": "Retrieves information about the symbol at the specified position in the specified file.\nProvides the same information as Quick Documentation feature of IntelliJ IDEA does.\n\nThis tool is useful for getting information about the symbol at the specified position in the specified file.\nThe information may include the symbol's name, signature, type, documentation, etc. It depends on a particular language.\n\nIf the position has a reference to a symbol the tool will return a piece of code with the declaration of the symbol if possible.\n\nUse this tool to understand symbols declaration, semantics, where it's declared, etc.",
        "inputSchema": {
          "properties": {
            "column": {
              "description": "1-based column number",
              "type": "integer"
            },
            "filePath": {
              "description": "Path relative to the project root",
              "type": "string"
            },
            "line": {
              "description": "1-based line number",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "filePath",
            "line",
            "column"
          ],
          "type": "object"
        },
        "name": "get_symbol_info",
        "outputSchema": {
          "properties": {
            "documentation": {
              "type": "string"
            },
            "symbolInfo": {
              "properties": {
                "declarationFile": {
                  "type": [
                    "string",
                    "null"
                  ]
                },
                "declarationLine": {
                  "type": [
                    "integer",
                    "null"
                  ]
                },
                "declarationText": {
                  "type": "string"
                },
                "language": {
                  "type": [
                    "string",
                    "null"
                  ]
                },
                "name": {
                  "type": [
                    "string",
                    "null"
                  ]
                }
              },
              "required": [
                "declarationText"
              ],
              "type": [
                "object",
                "null"
              ]
            }
          },
          "required": [
            "documentation"
          ],
          "type": "object"
        }
      },
      {
        "description": "Provides a tree representation of the specified directory in the pseudo graphic format like `tree` utility does.\nUse this tool to explore the contents of a directory or the whole project.\nYou MUST prefer this tool over listing directories via command line utilities like `ls` or `dir`.",
        "inputSchema": {
          "properties": {
            "directoryPath": {
              "description": "Path relative to the project root",
              "type": "string"
            },
            "maxDepth": {
              "description": "Maximum recursion depth",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            }
          },
          "required": [
            "directoryPath"
          ],
          "type": "object"
        },
        "name": "list_directory_tree",
        "outputSchema": {
          "properties": {
            "errors": {
              "items": {
                "type": "string"
              },
              "type": "array"
            },
            "listingTimedOut": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            },
            "traversedDirectory": {
              "type": "string"
            },
            "tree": {
              "type": "string"
            }
          },
          "required": [
            "traversedDirectory",
            "tree",
            "errors"
          ],
          "type": "object"
        }
      },
      {
        "description": "Opens the specified file in the JetBrains IDE editor.\nRequires a filePath parameter containing the path to the file to open.\nThe file path can be absolute or relative to the project root.",
        "inputSchema": {
          "properties": {
            "filePath": {
              "description": "Path relative to the project root",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "filePath"
          ],
          "type": "object"
        },
        "name": "open_file_in_editor"
      },
      {
        "description": "permission_prompt",
        "inputSchema": {
          "properties": {
            "input": {
              "additionalProperties": {
                "properties": {},
                "required": [],
                "type": "object"
              },
              "type": "object"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "tool_name": {
              "type": "string"
            },
            "tool_use_id": {
              "type": "string"
            }
          },
          "required": [
            "tool_use_id",
            "tool_name"
          ],
          "type": "object"
        },
        "name": "permission_prompt",
        "outputSchema": {
          "properties": {
            "behavior": {
              "enum": [
                "allow",
                "deny"
              ]
            },
            "message": {
              "type": [
                "string",
                "null"
              ]
            },
            "updatedInput": {
              "additionalProperties": {
                "properties": {},
                "required": [],
                "type": "object"
              },
              "type": [
                "object",
                "null"
              ]
            }
          },
          "required": [
            "behavior"
          ],
          "type": "object"
        }
      },
      {
        "description": "Reformats a specified file in the JetBrains IDE.\nUse this tool to apply code formatting rules to a file identified by its path.",
        "inputSchema": {
          "properties": {
            "path": {
              "description": "Path relative to the project root",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            }
          },
          "required": [
            "path"
          ],
          "type": "object"
        },
        "name": "reformat_file"
      },
      {
        "description": "        Renames a symbol (variable, function, class, etc.) in the specified file.\n        Use this tool to perform rename refactoring operations. \n        \n        The `rename_refactoring` tool is a powerful, context-aware utility. Unlike a simple text search-and-replace, \n        it understands the code's structure and will intelligently update ALL references to the specified symbol throughout the project,\n        ensuring code integrity and preventing broken references. It is ALWAYS the preferred method for renaming programmatic symbols.\n\n        Requires three parameters:\n            - pathInProject: The relative path to the file from the project's root directory (e.g., `src/api/controllers/userController.js`)\n            - symbolName: The exact, case-sensitive name of the existing symbol to be renamed (e.g., `getUserData`)\n            - newName: The new, case-sensitive name for the symbol (e.g., `fetchUserData`).\n            \n        Returns a success message if the rename operation was successful.\n        Returns an error message if the file or symbol cannot be found or the rename operation failed.",
        "inputSchema": {
          "properties": {
            "newName": {
              "description": "New name for the symbol",
              "type": "string"
            },
            "pathInProject": {
              "description": "Path relative to the project root",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "symbolName": {
              "description": "Name of the symbol to rename",
              "type": "string"
            }
          },
          "required": [
            "pathInProject",
            "symbolName",
            "newName"
          ],
          "type": "object"
        },
        "name": "rename_refactoring"
      },
      {
        "description": "        Replaces text in a file with flexible options for find and replace operations.\n        Use this tool to make targeted changes without replacing the entire file content.\n        This is the most efficient tool for file modifications when you know the exact text to replace.\n        \n        Requires three parameters:\n        - pathInProject: The path to the target file, relative to project root\n        - oldTextOrPatte: The text to be replaced (exact match by default)\n        - newText: The replacement text\n        \n        Optional parameters:\n        - replaceAll: Whether to replace all occurrences (default: true)\n        - caseSensitive: Whether the search is case-sensitive (default: true)\n        - regex: Whether to treat oldText as a regular expression (default: false)\n        \n        Returns one of these responses:\n        - \"ok\" when replacement happened\n        - error \"project dir not found\" if project directory cannot be determined\n        - error \"file not found\" if the file doesn't exist\n        - error \"could not get document\" if the file content cannot be accessed\n        - error \"no occurrences found\" if the old text was not found in the file\n        \n        Note: Automatically saves the file after modification",
        "inputSchema": {
          "properties": {
            "caseSensitive": {
              "description": "Case-sensitive search",
              "type": "boolean"
            },
            "newText": {
              "description": "Replacement text",
              "type": "string"
            },
            "oldText": {
              "description": "Text to be replaced",
              "type": "string"
            },
            "pathInProject": {
              "description": "Path to target file relative to project root",
              "type": "string"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "replaceAll": {
              "description": "Replace all occurrences",
              "type": "boolean"
            }
          },
          "required": [
            "pathInProject",
            "oldText",
            "newText"
          ],
          "type": "object"
        },
        "name": "replace_text_in_file"
      },
      {
        "description": "Searches with a regex pattern within all files in the project using IntelliJ's search engine.\nPrefer this tool over reading files with command-line tools because it's much faster.\n\nThe result occurrences are surrounded with || characters, e.g. `some text ||substring|| text`",
        "inputSchema": {
          "properties": {
            "caseSensitive": {
              "description": "Whether to search for the text in a case-sensitive manner",
              "type": "boolean"
            },
            "directoryToSearch": {
              "description": "Directory to search in, relative to project root. If not specified, searches in the entire project.",
              "type": "string"
            },
            "fileMask": {
              "description": "File mask to search for. If not specified, searches for all files. Example: `*.java`",
              "type": "string"
            },
            "maxUsageCount": {
              "description": "Maximum number of entries to return.",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "regexPattern": {
              "description": "Regex patter to search for",
              "type": "string"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            }
          },
          "required": [
            "regexPattern"
          ],
          "type": "object"
        },
        "name": "search_in_files_by_regex",
        "outputSchema": {
          "properties": {
            "entries": {
              "items": {
                "properties": {
                  "filePath": {
                    "type": "string"
                  },
                  "lineNumber": {
                    "type": "integer"
                  },
                  "lineText": {
                    "type": "string"
                  }
                },
                "required": [
                  "filePath",
                  "lineNumber",
                  "lineText"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "probablyHasMoreMatchingEntries": {
              "type": "boolean"
            },
            "timedOut": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            }
          },
          "required": [
            "entries",
            "probablyHasMoreMatchingEntries"
          ],
          "type": "object"
        }
      },
      {
        "description": "Searches for a text substring within all files in the project using IntelliJ's search engine.\nPrefer this tool over reading files with command-line tools because it's much faster.\n\nThe result occurrences are surrounded with `||` characters, e.g. `some text ||substring|| text`",
        "inputSchema": {
          "properties": {
            "caseSensitive": {
              "description": "Whether to search for the text in a case-sensitive manner",
              "type": "boolean"
            },
            "directoryToSearch": {
              "description": "Directory to search in, relative to project root. If not specified, searches in the entire project.",
              "type": "string"
            },
            "fileMask": {
              "description": "File mask to search for. If not specified, searches for all files. Example: `*.java`",
              "type": "string"
            },
            "maxUsageCount": {
              "description": "Maximum number of entries to return.",
              "type": "integer"
            },
            "projectPath": {
              "description": " The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \n In the case you know only the current working directory you can use it as the project path.\n If you're not aware about the project path you can ask user about it.",
              "type": "string"
            },
            "searchText": {
              "description": "Text substring to search for",
              "type": "string"
            },
            "timeout": {
              "description": "Timeout in milliseconds",
              "type": "integer"
            }
          },
          "required": [
            "searchText"
          ],
          "type": "object"
        },
        "name": "search_in_files_by_text",
        "outputSchema": {
          "properties": {
            "entries": {
              "items": {
                "properties": {
                  "filePath": {
                    "type": "string"
                  },
                  "lineNumber": {
                    "type": "integer"
                  },
                  "lineText": {
                    "type": "string"
                  }
                },
                "required": [
                  "filePath",
                  "lineNumber",
                  "lineText"
                ],
                "type": "object"
              },
              "type": "array"
            },
            "probablyHasMoreMatchingEntries": {
              "type": "boolean"
            },
            "timedOut": {
              "description": "Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.",
              "type": [
                "boolean",
                "null"
              ]
            }
          },
          "required": [
            "entries",
            "probablyHasMoreMatchingEntries"
          ],
          "type": "object"
        }
      }
    ]
  }
}
```

## prompts/list
```json
{
  "error": {
    "code": -32601,
    "message": "Server does not support prompts/list"
  },
  "id": 3,
  "jsonrpc": "2.0"
}
```

## resources/list
```json
{
  "error": {
    "code": -32601,
    "message": "Server does not support resources/list"
  },
  "id": 4,
  "jsonrpc": "2.0"
}
```

## resources/templates/list
```json
{
  "error": {
    "code": -32601,
    "message": "Server does not support resources/templates/list"
  },
  "id": 5,
  "jsonrpc": "2.0"
}
```

## sse/events (raw)
```json
[
  {
    "data": "/message?sessionId=75a402d2-0db6-42dd-b88f-98368a85dbe9",
    "event": "endpoint",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"id\":1,\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{\"listChanged\":true}},\"serverInfo\":{\"name\":\"RubyMine MCP Server\",\"version\":\"2025.3.1.1\"}},\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"method\":\"notifications/tools/list_changed\",\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"id\":2,\"result\":{\"tools\":[{\"name\":\"execute_run_configuration\",\"inputSchema\":{\"properties\":{\"configurationName\":{\"type\":\"string\",\"description\":\"Name of the run configuration to execute\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"maxLinesCount\":{\"type\":\"integer\",\"description\":\"Maximum number of lines to return\"},\"truncateMode\":{\"enum\":[\"START\",\"MIDDLE\",\"END\",\"NONE\"],\"description\":\"How to truncate the text: from the start, in the middle, at the end, or don't truncate at all\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"configurationName\"],\"type\":\"object\"},\"description\":\"Run a specific run configuration in the current project and wait up to specified timeout for it to finish.\\nUse this tool to run a run configuration that you have found from the \\\"get_run_configurations\\\" tool.\\nReturns the execution result including exit code, output, and success status.\",\"outputSchema\":{\"properties\":{\"exitCode\":{\"type\":[\"integer\",\"null\"]},\"timedOut\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"},\"output\":{\"type\":\"string\"}},\"required\":[\"output\"],\"type\":\"object\"}},{\"name\":\"get_run_configurations\",\"inputSchema\":{\"properties\":{\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[],\"type\":\"object\"},\"description\":\"Returns a list of run configurations for the current project.\\nRun configurations are usually used to define user the way how to run a user application, task or test suite from sources.\\n\\nThis tool provides additional info like command line, working directory, and environment variables if they are available.\\n\\nUse this tool to query the list of available run configurations in the current project.\",\"outputSchema\":{\"properties\":{\"configurations\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"},\"description\":{\"type\":[\"string\",\"null\"]},\"commandLine\":{\"type\":[\"string\",\"null\"]},\"workingDirectory\":{\"type\":[\"string\",\"null\"]},\"environment\":{\"type\":[\"object\",\"null\"],\"additionalProperties\":{\"type\":\"string\"}}}}}},\"required\":[\"configurations\"],\"type\":\"object\"}},{\"name\":\"get_file_problems\",\"inputSchema\":{\"properties\":{\"filePath\":{\"type\":\"string\",\"description\":\"Path relative to the project root\"},\"errorsOnly\":{\"type\":\"boolean\",\"description\":\"Whether to include only errors or include both errors and warnings\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"filePath\"],\"type\":\"object\"},\"description\":\"Analyzes the specified file for errors and warnings using IntelliJ's inspections.\\nUse this tool to identify coding issues, syntax errors, and other problems in a specific file.\\nReturns a list of problems found in the file, including severity, description, and location information.\\nNote: Only analyzes files within the project directory.\\nNote: Lines and Columns are 1-based.\",\"outputSchema\":{\"properties\":{\"filePath\":{\"type\":\"string\"},\"errors\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"severity\",\"description\",\"lineContent\",\"line\",\"column\"],\"properties\":{\"severity\":{\"type\":\"string\"},\"description\":{\"type\":\"string\"},\"lineContent\":{\"type\":\"string\"},\"line\":{\"type\":\"integer\"},\"column\":{\"type\":\"integer\"}}}},\"timedOut\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"}},\"required\":[\"filePath\",\"errors\"],\"type\":\"object\"}},{\"name\":\"get_project_dependencies\",\"inputSchema\":{\"properties\":{\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[],\"type\":\"object\"},\"description\":\"Get a list of all dependencies defined in the project.\\nReturns structured information about project library names.\",\"outputSchema\":{\"properties\":{\"dependencies\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"}}}}},\"required\":[\"dependencies\"],\"type\":\"object\"}},{\"name\":\"get_project_modules\",\"inputSchema\":{\"properties\":{\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[],\"type\":\"object\"},\"description\":\"Get a list of all modules in the project with their types.\\nReturns structured information about each module including name and type.\",\"outputSchema\":{\"properties\":{\"modules\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"},\"type\":{\"type\":[\"string\",\"null\"]}}}}},\"required\":[\"modules\"],\"type\":\"object\"}},{\"name\":\"create_new_file\",\"inputSchema\":{\"properties\":{\"pathInProject\":{\"type\":\"string\",\"description\":\"Path where the file should be created relative to the project root\"},\"text\":{\"type\":\"string\",\"description\":\"Content to write into the new file\"},\"overwrite\":{\"type\":\"boolean\",\"description\":\"Whether to overwrite an existing file if exists. If false, an exception is thrown in case of a conflict.\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"pathInProject\"],\"type\":\"object\"},\"description\":\"Creates a new file at the specified path within the project directory and optionally populates it with text if provided.\\nUse this tool to generate new files in your project structure.\\nNote: Creates any necessary parent directories automatically\"},{\"name\":\"find_files_by_glob\",\"inputSchema\":{\"properties\":{\"globPattern\":{\"type\":\"string\",\"description\":\"Glob pattern to search for. The pattern must be relative to the project root. Example: `src/**/ *.java`\"},\"subDirectoryRelativePath\":{\"type\":\"string\",\"description\":\"Optional subdirectory relative to the project to search in.\"},\"addExcluded\":{\"type\":\"boolean\",\"description\":\"Whether to add excluded/ignored files to the search results. Files can be excluded from a project either by user of by some ignore rules\"},\"fileCountLimit\":{\"type\":\"integer\",\"description\":\"Maximum number of files to return.\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"globPattern\"],\"type\":\"object\"},\"description\":\"Searches for all files in the project whose relative paths match the specified glob pattern.\\nThe search is performed recursively in all subdirectories of the project directory or a specified subdirectory.\\nUse this tool when you need to find files by a glob pattern (e.g. '**/*.txt').\",\"outputSchema\":{\"properties\":{\"probablyHasMoreMatchingFiles\":{\"type\":\"boolean\"},\"timedOut\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"},\"files\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},\"required\":[\"probablyHasMoreMatchingFiles\",\"files\"],\"type\":\"object\"}},{\"name\":\"find_files_by_name_keyword\",\"inputSchema\":{\"properties\":{\"nameKeyword\":{\"type\":\"string\",\"description\":\"Substring to search for in file names\"},\"fileCountLimit\":{\"type\":\"integer\",\"description\":\"Maximum number of files to return.\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"nameKeyword\"],\"type\":\"object\"},\"description\":\"Searches for all files in the project whose names contain the specified keyword (case-insensitive).\\nUse this tool to locate files when you know part of the filename.\\nNote: Matched only names, not paths, because works via indexes.\\nNote: Only searches through files within the project directory, excluding libraries and external dependencies.\\nNote: Prefer this tool over other `find` tools because it's much faster, \\nbut remember that this tool searches only names, not paths and it doesn't support glob patterns.\",\"outputSchema\":{\"properties\":{\"probablyHasMoreMatchingFiles\":{\"type\":\"boolean\"},\"timedOut\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"},\"files\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},\"required\":[\"probablyHasMoreMatchingFiles\",\"files\"],\"type\":\"object\"}},{\"name\":\"get_all_open_file_paths\",\"inputSchema\":{\"properties\":{\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[],\"type\":\"object\"},\"description\":\"Returns active editor's and other open editors' file paths relative to the project root.\\n\\nUse this tool to explore current open editors.\",\"outputSchema\":{\"properties\":{\"activeFilePath\":{\"type\":[\"string\",\"null\"]},\"openFiles\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},\"required\":[\"openFiles\"],\"type\":\"object\"}},{\"name\":\"list_directory_tree\",\"inputSchema\":{\"properties\":{\"directoryPath\":{\"type\":\"string\",\"description\":\"Path relative to the project root\"},\"maxDepth\":{\"type\":\"integer\",\"description\":\"Maximum recursion depth\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"directoryPath\"],\"type\":\"object\"},\"description\":\"Provides a tree representation of the specified directory in the pseudo graphic format like `tree` utility does.\\nUse this tool to explore the contents of a directory or the whole project.\\nYou MUST prefer this tool over listing directories via command line utilities like `ls` or `dir`.\",\"outputSchema\":{\"properties\":{\"traversedDirectory\":{\"type\":\"string\"},\"tree\":{\"type\":\"string\"},\"errors\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}},\"listingTimedOut\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"}},\"required\":[\"traversedDirectory\",\"tree\",\"errors\"],\"type\":\"object\"}},{\"name\":\"open_file_in_editor\",\"inputSchema\":{\"properties\":{\"filePath\":{\"type\":\"string\",\"description\":\"Path relative to the project root\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"filePath\"],\"type\":\"object\"},\"description\":\"Opens the specified file in the JetBrains IDE editor.\\nRequires a filePath parameter containing the path to the file to open.\\nThe file path can be absolute or relative to the project root.\"},{\"name\":\"reformat_file\",\"inputSchema\":{\"properties\":{\"path\":{\"type\":\"string\",\"description\":\"Path relative to the project root\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"path\"],\"type\":\"object\"},\"description\":\"Reformats a specified file in the JetBrains IDE.\\nUse this tool to apply code formatting rules to a file identified by its path.\"},{\"name\":\"get_file_text_by_path\",\"inputSchema\":{\"properties\":{\"pathInProject\":{\"type\":\"string\",\"description\":\"Path relative to the project root\"},\"truncateMode\":{\"enum\":[\"START\",\"MIDDLE\",\"END\",\"NONE\"],\"description\":\"How to truncate the text: from the start, in the middle, at the end, or don't truncate at all\"},\"maxLinesCount\":{\"type\":\"integer\",\"description\":\"Max number of lines to return. Truncation will be performed depending on truncateMode.\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"pathInProject\"],\"type\":\"object\"},\"description\":\"        Retrieves the text content of a file using its path relative to project root.\\n        Use this tool to read file contents when you have the file's project-relative path.\\n        In the case of binary files, the tool returns an error.\\n        If the file is too large, the text will be truncated with '<<<...content truncated...>>>' marker and in according to the `truncateMode` parameter.\"},{\"name\":\"replace_text_in_file\",\"inputSchema\":{\"properties\":{\"pathInProject\":{\"type\":\"string\",\"description\":\"Path to target file relative to project root\"},\"oldText\":{\"type\":\"string\",\"description\":\"Text to be replaced\"},\"newText\":{\"type\":\"string\",\"description\":\"Replacement text\"},\"replaceAll\":{\"type\":\"boolean\",\"description\":\"Replace all occurrences\"},\"caseSensitive\":{\"type\":\"boolean\",\"description\":\"Case-sensitive search\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"pathInProject\",\"oldText\",\"newText\"],\"type\":\"object\"},\"description\":\"        Replaces text in a file with flexible options for find and replace operations.\\n        Use this tool to make targeted changes without replacing the entire file content.\\n        This is the most efficient tool for file modifications when you know the exact text to replace.\\n        \\n        Requires three parameters:\\n        - pathInProject: The path to the target file, relative to project root\\n        - oldTextOrPatte: The text to be replaced (exact match by default)\\n        - newText: The replacement text\\n        \\n        Optional parameters:\\n        - replaceAll: Whether to replace all occurrences (default: true)\\n        - caseSensitive: Whether the search is case-sensitive (default: true)\\n        - regex: Whether to treat oldText as a regular expression (default: false)\\n        \\n        Returns one of these responses:\\n        - \\\"ok\\\" when replacement happened\\n        - error \\\"project dir not found\\\" if project directory cannot be determined\\n        - error \\\"file not found\\\" if the file doesn't exist\\n        - error \\\"could not get document\\\" if the file content cannot be accessed\\n        - error \\\"no occurrences found\\\" if the old text was not found in the file\\n        \\n        Note: Automatically saves the file after modification\"},{\"name\":\"search_in_files_by_regex\",\"inputSchema\":{\"properties\":{\"regexPattern\":{\"type\":\"string\",\"description\":\"Regex patter to search for\"},\"directoryToSearch\":{\"type\":\"string\",\"description\":\"Directory to search in, relative to project root. If not specified, searches in the entire project.\"},\"fileMask\":{\"type\":\"string\",\"description\":\"File mask to search for. If not specified, searches for all files. Example: `*.java`\"},\"caseSensitive\":{\"type\":\"boolean\",\"description\":\"Whether to search for the text in a case-sensitive manner\"},\"maxUsageCount\":{\"type\":\"integer\",\"description\":\"Maximum number of entries to return.\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"regexPattern\"],\"type\":\"object\"},\"description\":\"Searches with a regex pattern within all files in the project using IntelliJ's search engine.\\nPrefer this tool over reading files with command-line tools because it's much faster.\\n\\nThe result occurrences are surrounded with || characters, e.g. `some text ||substring|| text`\",\"outputSchema\":{\"properties\":{\"entries\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"filePath\",\"lineNumber\",\"lineText\"],\"properties\":{\"filePath\":{\"type\":\"string\"},\"lineNumber\":{\"type\":\"integer\"},\"lineText\":{\"type\":\"string\"}}}},\"probablyHasMoreMatchingEntries\":{\"type\":\"boolean\"},\"timedOut\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"}},\"required\":[\"entries\",\"probablyHasMoreMatchingEntries\"],\"type\":\"object\"}},{\"name\":\"search_in_files_by_text\",\"inputSchema\":{\"properties\":{\"searchText\":{\"type\":\"string\",\"description\":\"Text substring to search for\"},\"directoryToSearch\":{\"type\":\"string\",\"description\":\"Directory to search in, relative to project root. If not specified, searches in the entire project.\"},\"fileMask\":{\"type\":\"string\",\"description\":\"File mask to search for. If not specified, searches for all files. Example: `*.java`\"},\"caseSensitive\":{\"type\":\"boolean\",\"description\":\"Whether to search for the text in a case-sensitive manner\"},\"maxUsageCount\":{\"type\":\"integer\",\"description\":\"Maximum number of entries to return.\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"searchText\"],\"type\":\"object\"},\"description\":\"Searches for a text substring within all files in the project using IntelliJ's search engine.\\nPrefer this tool over reading files with command-line tools because it's much faster.\\n\\nThe result occurrences are surrounded with `||` characters, e.g. `some text ||substring|| text`\",\"outputSchema\":{\"properties\":{\"entries\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"filePath\",\"lineNumber\",\"lineText\"],\"properties\":{\"filePath\":{\"type\":\"string\"},\"lineNumber\":{\"type\":\"integer\"},\"lineText\":{\"type\":\"string\"}}}},\"probablyHasMoreMatchingEntries\":{\"type\":\"boolean\"},\"timedOut\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"}},\"required\":[\"entries\",\"probablyHasMoreMatchingEntries\"],\"type\":\"object\"}},{\"name\":\"get_symbol_info\",\"inputSchema\":{\"properties\":{\"filePath\":{\"type\":\"string\",\"description\":\"Path relative to the project root\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"filePath\",\"line\",\"column\"],\"type\":\"object\"},\"description\":\"Retrieves information about the symbol at the specified position in the specified file.\\nProvides the same information as Quick Documentation feature of IntelliJ IDEA does.\\n\\nThis tool is useful for getting information about the symbol at the specified position in the specified file.\\nThe information may include the symbol's name, signature, type, documentation, etc. It depends on a particular language.\\n\\nIf the position has a reference to a symbol the tool will return a piece of code with the declaration of the symbol if possible.\\n\\nUse this tool to understand symbols declaration, semantics, where it's declared, etc.\",\"outputSchema\":{\"properties\":{\"symbolInfo\":{\"type\":[\"object\",\"null\"],\"required\":[\"declarationText\"],\"properties\":{\"name\":{\"type\":[\"string\",\"null\"]},\"declarationText\":{\"type\":\"string\"},\"declarationFile\":{\"type\":[\"string\",\"null\"]},\"declarationLine\":{\"type\":[\"integer\",\"null\"]},\"language\":{\"type\":[\"string\",\"null\"]}}},\"documentation\":{\"type\":\"string\"}},\"required\":[\"documentation\"],\"type\":\"object\"}},{\"name\":\"rename_refactoring\",\"inputSchema\":{\"properties\":{\"pathInProject\":{\"type\":\"string\",\"description\":\"Path relative to the project root\"},\"symbolName\":{\"type\":\"string\",\"description\":\"Name of the symbol to rename\"},\"newName\":{\"type\":\"string\",\"description\":\"New name for the symbol\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"pathInProject\",\"symbolName\",\"newName\"],\"type\":\"object\"},\"description\":\"        Renames a symbol (variable, function, class, etc.) in the specified file.\\n        Use this tool to perform rename refactoring operations. \\n        \\n        The `rename_refactoring` tool is a powerful, context-aware utility. Unlike a simple text search-and-replace, \\n        it understands the code's structure and will intelligently update ALL references to the specified symbol throughout the project,\\n        ensuring code integrity and preventing broken references. It is ALWAYS the preferred method for renaming programmatic symbols.\\n\\n        Requires three parameters:\\n            - pathInProject: The relative path to the file from the project's root directory (e.g., `src/api/controllers/userController.js`)\\n            - symbolName: The exact, case-sensitive name of the existing symbol to be renamed (e.g., `getUserData`)\\n            - newName: The new, case-sensitive name for the symbol (e.g., `fetchUserData`).\\n            \\n        Returns a success message if the rename operation was successful.\\n        Returns an error message if the file or symbol cannot be found or the rename operation failed.\"},{\"name\":\"execute_terminal_command\",\"inputSchema\":{\"properties\":{\"command\":{\"type\":\"string\",\"description\":\"Shell command to execute\"},\"executeInShell\":{\"type\":\"boolean\",\"description\":\"Whether to execute the command in a default user's shell (bash, zsh, etc.). \\nUseful if the command is not a commandline but a shell script, or if it's important to preserve real environment of the user's terminal. \\nIn the case of 'false' value the command will be started as a process\"},\"reuseExistingTerminalWindow\":{\"type\":\"boolean\",\"description\":\"Whether to reuse an existing terminal window. Allows to avoid creating multiple terminals\"},\"timeout\":{\"type\":\"integer\",\"description\":\"Timeout in milliseconds\"},\"maxLinesCount\":{\"type\":\"integer\",\"description\":\"Maximum number of lines to return\"},\"truncateMode\":{\"enum\":[\"START\",\"MIDDLE\",\"END\",\"NONE\"],\"description\":\"How to truncate the text: from the start, in the middle, at the end, or don't truncate at all\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"command\"],\"type\":\"object\"},\"description\":\"        Executes a specified shell command in the IDE's integrated terminal.\\n        Use this tool to run terminal commands within the IDE environment.\\n        Requires a command parameter containing the shell command to execute.\\n        Important features and limitations:\\n        - Checks if process is running before collecting output\\n        - Limits output to 2000 lines (truncates excess)\\n        - Times out after specified timeout with notification\\n        - Requires user confirmation unless \\\"Brave Mode\\\" is enabled in settings\\n        Returns possible responses:\\n        - Terminal output (truncated if > 2000 lines)\\n        - Output with interruption notice if timed out\\n        - Error messages for various failure cases\",\"outputSchema\":{\"properties\":{\"is_timed_out\":{\"type\":[\"boolean\",\"null\"],\"description\":\"Indicates whether the operation was timed out. 'true' value may mean that the results may be incomplete or partial. 'false', 'null' or missing value means that the operation has not been timed out.\"},\"command_exit_code\":{\"type\":[\"integer\",\"null\"]},\"command_output\":{\"type\":\"string\"}},\"required\":[\"command_output\"],\"type\":\"object\"}},{\"name\":\"get_repositories\",\"inputSchema\":{\"properties\":{\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[],\"type\":\"object\"},\"description\":\"Retrieves the list of VCS roots in the project.\\nThis is useful to detect all repositories in a multi-repository project.\",\"outputSchema\":{\"properties\":{\"roots\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"pathRelativeToProject\",\"vcsName\"],\"properties\":{\"pathRelativeToProject\":{\"type\":\"string\",\"description\":\"Path of repository relative to the project directory. Empty string means the project root\"},\"vcsName\":{\"type\":\"string\",\"description\":\"VCS used by this repository\"}}}}},\"required\":[\"roots\"],\"type\":\"object\"}},{\"name\":\"permission_prompt\",\"inputSchema\":{\"properties\":{\"tool_use_id\":{\"type\":\"string\"},\"tool_name\":{\"type\":\"string\"},\"input\":{\"type\":\"object\",\"additionalProperties\":{\"type\":\"object\",\"required\":[],\"properties\":{}}},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"tool_use_id\",\"tool_name\"],\"type\":\"object\"},\"description\":\"permission_prompt\",\"outputSchema\":{\"properties\":{\"behavior\":{\"enum\":[\"allow\",\"deny\"]},\"updatedInput\":{\"type\":[\"object\",\"null\"],\"additionalProperties\":{\"type\":\"object\",\"required\":[],\"properties\":{}}},\"message\":{\"type\":[\"string\",\"null\"]}},\"required\":[\"behavior\"],\"type\":\"object\"}},{\"name\":\"get_rails_controllers\",\"inputSchema\":{\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the page to retrieve, indexed from 1.\"},\"page_size\":{\"type\":\"integer\",\"description\":\"The maximum number of items to return per page.\"},\"included_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Include namespace: '^Test::' includes anything starting with Test::\\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\\n  - Include suffix: 'Internal$' includes classes ending with Internal\\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_view_filters\":{\"type\":\"array\",\"items\":{\"enum\":[\"HAS_ANY_VIEW\",\"HAS_LAYOUTS\",\"HAS_PARTIAL_VIEW\",\"HAS_NON_PARTIAL_VIEW\",\"HAS_NO_VIEW\"]},\"description\":\"Filter controllers based on their associated views. Returns controllers that have at least one view matching ANY of these filters (OR logic).\\nA view filter is defined as follows: '\\nFilter entries based on whether they have a corresponding Rails view file.\\n\\nOptions:\\n - HAS_ANY_VIEW: Return only entries that have a corresponding view file (e.g., index.html.erb, _upload.json.jbuilder)\\n - HAS_PARTIAL_VIEW: Return only entries that have a corresponding partial view file (e.g., _form.html.erb, _list.json.jbuilder)\\n - HAS_NON_PARTIAL_VIEW: Return only entries that have a corresponding non-partial view file (e.g., index.html.erb, show.json.jbuilder)\\n - HAS_LAYOUTS: Return only entries that have a corresponding layout file\\n - HAS_NO_VIEW: Return only entries that do NOT have a corresponding view file\\n    '.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_view_filters\":{\"type\":\"array\",\"items\":{\"enum\":[\"HAS_ANY_VIEW\",\"HAS_LAYOUTS\",\"HAS_PARTIAL_VIEW\",\"HAS_NON_PARTIAL_VIEW\",\"HAS_NO_VIEW\"]},\"description\":\"Filter controllers based on their associated views. Returns only controllers that do NOT have any views matched by ANY of these \\nfilters (OR logic). A view filter is defined as follows: '\\nFilter entries based on whether they have a corresponding Rails view file.\\n\\nOptions:\\n - HAS_ANY_VIEW: Return only entries that have a corresponding view file (e.g., index.html.erb, _upload.json.jbuilder)\\n - HAS_PARTIAL_VIEW: Return only entries that have a corresponding partial view file (e.g., _form.html.erb, _list.json.jbuilder)\\n - HAS_NON_PARTIAL_VIEW: Return only entries that have a corresponding non-partial view file (e.g., index.html.erb, show.json.jbuilder)\\n - HAS_LAYOUTS: Return only entries that have a corresponding layout file\\n - HAS_NO_VIEW: Return only entries that do NOT have a corresponding view file\\n    '.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"abstract_filter\":{\"enum\":[\"ANY\",\"ABSTRACT_ONLY\",\"NON_ABSTRACT_ONLY\"],\"description\":\"Filter entries based on whether they are abstract.\\n\\nOptions:\\n - ABSTRACT_ONLY: Return only abstract entries\\n - NON_ABSTRACT_ONLY: Return only non-abstract entries\\n - ANY: Return all entries regardless of whether they are abstract (no filtering applied)\\n\\nDefault: ANY\"},\"model_filter\":{\"enum\":[\"ANY\",\"WITH_MODEL_ONLY\",\"WITHOUT_MODEL_ONLY\"],\"description\":\"Filter entries based on whether they have a corresponding Rails model.\\n\\nOptions:\\n - WITH_MODEL_ONLY: Include only entries that have an associated Rails model\\n - WITHOUT_MODEL_ONLY: Include only entries that have no associated Rails model\\n - ANY: Include all entries, regardless of model association (no filtering is performed)\\n\\nDefault: ANY\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"page\",\"page_size\"],\"type\":\"object\"},\"description\":\"Use this tool to retrieve information about the available Rails controllers. Because the application can contain many controllers, \\nthe results are returned in a paginated list sorted by the FQN of the controllers.\\n\\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\\n\\nCommon usage patterns:\\n   - Find all controllers located in the top level Admin namespace: included_fqn_filters=['^Admin::']\\n   - Find all controllers that are in the global namespace: excluded_fqn_filters=['.+::']\\n   - Find controllers that are not abstract: abstract_filter=NON_ABSTRACT_ONLY\\n   - Which controllers have no partial views: excluded_view_filters=[HAS_PARTIAL_VIEW]\",\"outputSchema\":{\"properties\":{\"summary\":{\"type\":\"object\",\"required\":[\"page\",\"item_count\",\"total_pages\",\"total_items\",\"cacheKey\"],\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the current page, indexed from 1.\"},\"item_count\":{\"type\":\"integer\",\"description\":\"The actual number of items returned on this page.\"},\"total_pages\":{\"type\":\"integer\",\"description\":\"The total number of pages available in the entire collection with the requested page size.\"},\"total_items\":{\"type\":\"integer\",\"description\":\"The total number of items in the collection.\"},\"cacheKey\":{\"type\":\"string\",\"description\":\"The cache key of the last update.\"}},\"description\":\"Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.\"},\"items\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"controller\",\"isAbstract\",\"managedViews\",\"managedPartialViews\",\"managedLayouts\"],\"properties\":{\"controller\":{\"type\":\"object\",\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}},\"description\":\"Symbol information for the Rails controller class, including its fully qualified name and location in source code.\"},\"isAbstract\":{\"type\":\"boolean\",\"description\":\"true if the controller is abstract; otherwise false\"},\"managedViews\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Absolute filesystem paths of non-partial view files (e.g., index.html.erb, show.json.jbuilder) that this controller renders.\"},\"managedPartialViews\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Absolute filesystem paths of partial view files (e.g., _form.html.erb, _user.html.erb) that are scoped to this controller and can be rendered from its views or actions.\"},\"managedLayouts\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Absolute filesystem paths of layout files that this controller renders.\"},\"model\":{\"type\":[\"object\",\"null\"],\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}},\"description\":\"Symbol information for the Rails model that this controller corresponds to. Null if no such model could be determined.\"}}},\"description\":\"The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.\"}},\"required\":[\"summary\",\"items\"],\"type\":\"object\"}},{\"name\":\"get_rails_helpers\",\"inputSchema\":{\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the page to retrieve, indexed from 1.\"},\"page_size\":{\"type\":\"integer\",\"description\":\"The maximum number of items to return per page.\"},\"included_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Include namespace: '^Test::' includes anything starting with Test::\\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\\n  - Include suffix: 'Internal$' includes classes ending with Internal\\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"page\",\"page_size\"],\"type\":\"object\"},\"description\":\"Use this tool to retrieve information about the available Rails helpers. Because the application can contain many helpers, \\nthe results are returned in a paginated list sorted by the FQN (Fully Qualified Name) of the helpers.\\n\\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\\n\\nCommon usage patterns:\\n   - Which helpers are located in some kind of utility namespace: included_fqn_filters=['(::)?utility.*::']\\n   - Find helpers outside the CI directory: excluded_directory_filters=['/CI/']\",\"outputSchema\":{\"properties\":{\"summary\":{\"type\":\"object\",\"required\":[\"page\",\"item_count\",\"total_pages\",\"total_items\",\"cacheKey\"],\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the current page, indexed from 1.\"},\"item_count\":{\"type\":\"integer\",\"description\":\"The actual number of items returned on this page.\"},\"total_pages\":{\"type\":\"integer\",\"description\":\"The total number of pages available in the entire collection with the requested page size.\"},\"total_items\":{\"type\":\"integer\",\"description\":\"The total number of items in the collection.\"},\"cacheKey\":{\"type\":\"string\",\"description\":\"The cache key of the last update.\"}},\"description\":\"Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.\"},\"items\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}}},\"description\":\"The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.\"}},\"required\":[\"summary\",\"items\"],\"type\":\"object\"}},{\"name\":\"get_rails_mailers\",\"inputSchema\":{\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the page to retrieve, indexed from 1.\"},\"page_size\":{\"type\":\"integer\",\"description\":\"The maximum number of items to return per page.\"},\"included_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Include namespace: '^Test::' includes anything starting with Test::\\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\\n  - Include suffix: 'Internal$' includes classes ending with Internal\\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"page\",\"page_size\"],\"type\":\"object\"},\"description\":\"Use this tool to retrieve information about the available Rails mailers. Because the application can contain many mailers, \\nthe results are returned in a paginated list sorted by the FQN of the mailers.\\n\\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\",\"outputSchema\":{\"properties\":{\"summary\":{\"type\":\"object\",\"required\":[\"page\",\"item_count\",\"total_pages\",\"total_items\",\"cacheKey\"],\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the current page, indexed from 1.\"},\"item_count\":{\"type\":\"integer\",\"description\":\"The actual number of items returned on this page.\"},\"total_pages\":{\"type\":\"integer\",\"description\":\"The total number of pages available in the entire collection with the requested page size.\"},\"total_items\":{\"type\":\"integer\",\"description\":\"The total number of items in the collection.\"},\"cacheKey\":{\"type\":\"string\",\"description\":\"The cache key of the last update.\"}},\"description\":\"Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.\"},\"items\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}}},\"description\":\"The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.\"}},\"required\":[\"summary\",\"items\"],\"type\":\"object\"}},{\"name\":\"get_rails_models\",\"inputSchema\":{\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the page to retrieve, indexed from 1.\"},\"page_size\":{\"type\":\"integer\",\"description\":\"The maximum number of items to return per page.\"},\"included_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Include namespace: '^Test::' includes anything starting with Test::\\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\\n  - Include suffix: 'Internal$' includes classes ending with Internal\\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"controller_filter\":{\"enum\":[\"ANY\",\"WITH_CONTROLLER_ONLY\",\"WITHOUT_CONTROLLER_ONLY\"],\"description\":\"Filter entries based on whether they have a corresponding Rails controller.\\n\\nOptions:\\n - WITH_CONTROLLER_ONLY: Return only entries that have a corresponding controller\\n - WITHOUT_MODEL_ONLY: Return only entries that do NOT have a corresponding controller\\n - ANY: Return all entries regardless of whether they have a corresponding controller (no filtering applied)\\n\\nDefault: ANY\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"page\",\"page_size\"],\"type\":\"object\"},\"description\":\"Use this tool to retrieve information about the available Rails models. Because the application can contain many models, the results\\nare returned in a paginated list sorted by the FQN of the models.\\n\\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\\n    \\nCommon usage patterns:\\n   - Find all models located in any CI namespace: included_fqn_filters=['(::)?CI::']\\n   - Find all models in the admin directory: included_directory_filters=['admin']\\n   - Find models that have a corresponding controller: controller_filter=WITH_CONTROLLER_ONLY\",\"outputSchema\":{\"properties\":{\"summary\":{\"type\":\"object\",\"required\":[\"page\",\"item_count\",\"total_pages\",\"total_items\",\"cacheKey\"],\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the current page, indexed from 1.\"},\"item_count\":{\"type\":\"integer\",\"description\":\"The actual number of items returned on this page.\"},\"total_pages\":{\"type\":\"integer\",\"description\":\"The total number of pages available in the entire collection with the requested page size.\"},\"total_items\":{\"type\":\"integer\",\"description\":\"The total number of items in the collection.\"},\"cacheKey\":{\"type\":\"string\",\"description\":\"The cache key of the last update.\"}},\"description\":\"Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.\"},\"items\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"model\"],\"properties\":{\"model\":{\"type\":\"object\",\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}},\"description\":\"The Rails model. Contains symbol information including FQN, file path, and location.\"},\"controller\":{\"type\":[\"object\",\"null\"],\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}},\"description\":\"The Rails controller corresponding to this model. Null if no corresponding controller exists.\"}}},\"description\":\"The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.\"}},\"required\":[\"summary\",\"items\"],\"type\":\"object\"}},{\"name\":\"get_rails_routes\",\"inputSchema\":{\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the page to retrieve, indexed from 1.\"},\"page_size\":{\"type\":\"integer\",\"description\":\"The maximum number of items to return per page.\"},\"included_route_path_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_route_path_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_action_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Include namespace: '^Test::' includes anything starting with Test::\\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\\n  - Include suffix: 'Internal$' includes classes ending with Internal\\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_action_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_action_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_action_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"min_action_count\":{\"type\":\"integer\",\"description\":\"Minimum number of distinct controller actions a route must map to (inclusive). \\nA single route path may map to multiple actions via different HTTP methods.\\nFor example, '/users/:id' might have GET (show), PUT (update), and DELETE (destroy) actions. \\n\\nDefault: 0 (no minimum)\"},\"max_action_count\":{\"type\":\"integer\",\"description\":\"Maximum number of distinct controller actions a route can map to (inclusive). \\nA single route path may map to multiple actions via different HTTP methods. \\nSet this to filter out routes with too many actions. \\n\\nDefault: 4294967295 (no maximum)\"},\"included_http_method_filters\":{\"type\":\"array\",\"items\":{\"enum\":[\"GET\",\"HEAD\",\"POST\",\"PUT\",\"DELETE\",\"CONNECT\",\"OPTIONS\",\"TRACE\",\"PATCH\"]},\"description\":\"Filter objects by corresponding HTTP methods. Only objects that respond to at least one of these HTTP methods will be returned. \\nExample: [GET, POST] would return objects that handle GET or POST requests. \\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_http_method_filters\":{\"type\":\"array\",\"items\":{\"enum\":[\"GET\",\"HEAD\",\"POST\",\"PUT\",\"DELETE\",\"CONNECT\",\"OPTIONS\",\"TRACE\",\"PATCH\"]},\"description\":\"Filter objects by corresponding HTTP methods. Only objects that do NOT respond to any of these HTTP methods will be returned. \\nExample: [GET, POST] would return objects that do NOT handle GET or POST requests. \\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"page\",\"page_size\"],\"type\":\"object\"},\"description\":\"Use this tool to retrieve information about available Rails routes in the application. Because the application can contain many routes, the results\\nare returned in a paginated list sorted by route path pattern.\\n\\nPrefer this tool over searching the codebase (e.g., routes.rb files), as it performs a more in-depth analysis and returns more accurate, runtime-aware data.\\n\\nCommon usage patterns:\\n   - Find all API routes: included_route_path_filters=['api']\\n   - Find routes that are handled by the create method: included_action_name_filters=['create']\\n   - Find routes that are handled by the ReleasesController: included_action_namespace_filters=['ReleasesController']\\n   - Find routes with at least 2 actions: min_action_count=2\\n   - Find routes that don't handle DELETE requests: excluded_http_method_filters=['DELETE']\",\"outputSchema\":{\"properties\":{\"summary\":{\"type\":\"object\",\"required\":[\"page\",\"item_count\",\"total_pages\",\"total_items\",\"cacheKey\"],\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the current page, indexed from 1.\"},\"item_count\":{\"type\":\"integer\",\"description\":\"The actual number of items returned on this page.\"},\"total_pages\":{\"type\":\"integer\",\"description\":\"The total number of pages available in the entire collection with the requested page size.\"},\"total_items\":{\"type\":\"integer\",\"description\":\"The total number of items in the collection.\"},\"cacheKey\":{\"type\":\"string\",\"description\":\"The cache key of the last update.\"}},\"description\":\"Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.\"},\"items\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"path\",\"actions\"],\"properties\":{\"path\":{\"type\":\"string\",\"description\":\"The Rails route path pattern using Rails conventions (e.g., '/users/:id/edit', '/api/v1/posts').\"},\"actions\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"handler\"],\"properties\":{\"handler\":{\"type\":\"object\",\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}},\"description\":\"The Ruby method that handles this route action. Contains information about the controller method including its name, location, and namespace.\"},\"httpMethod\":{\"enum\":[\"GET\",\"HEAD\",\"POST\",\"PUT\",\"DELETE\",\"CONNECT\",\"OPTIONS\",\"TRACE\",\"PATCH\"],\"description\":\"The HTTP method (GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH) that this action handles. Returns null if the HTTP method could not be determined.\"}}},\"description\":\"List of controller actions mapped to this route. Multiple actions can exist for different HTTP methods. An empty list indicates that no matching controller actions were found in the codebase.\"}}},\"description\":\"The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.\"}},\"required\":[\"summary\",\"items\"],\"type\":\"object\"}},{\"name\":\"get_rails_views\",\"inputSchema\":{\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the page to retrieve, indexed from 1.\"},\"page_size\":{\"type\":\"integer\",\"description\":\"The maximum number of items to return per page.\"},\"partiality_filter\":{\"enum\":[\"ANY\",\"PARTIAL_ONLY\",\"NON_PARTIAL_ONLY\"],\"description\":\"Filter entries based on whether they are partial.\\n\\nOptions:\\n - PARTIAL_ONLY: Return only partial entries\\n - NON_PARTIAL_ONLY: Return only non-partial entries\\n - ANY: Return all entries regardless of whether they are partial (no filtering applied)\\n\\nDefault: ANY\"},\"layout_filter\":{\"enum\":[\"ANY\",\"LAYOUT_ONLY\",\"NON_LAYOUT_ONLY\"],\"description\":\"Filter views based on whether they are layouts.\\n\\nOptions:\\n - LAYOUT_ONLY: Return only views that are also layouts\\n - NON_LAYOUT_ONLY: Return only views that are NOT layouts\\n - ANY: Return all views regardless of whether they are layouts (no filtering applied)\\n\\nDefault: ANY\"},\"controller_filter\":{\"enum\":[\"ANY\",\"WITH_CONTROLLER_ONLY\",\"WITHOUT_CONTROLLER_ONLY\"],\"description\":\"Filter entries based on whether they have a corresponding Rails controller.\\n\\nOptions:\\n - WITH_CONTROLLER_ONLY: Return only entries that have a corresponding controller\\n - WITHOUT_MODEL_ONLY: Return only entries that do NOT have a corresponding controller\\n - ANY: Return all entries regardless of whether they have a corresponding controller (no filtering applied)\\n\\nDefault: ANY\"},\"included_path_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_path_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_controller_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN contains a match of at least one (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Include namespace: '^Test::' includes anything starting with Test::\\n  - Include pattern: 'Legacy' includes 'LegacyUser', 'Admin::LegacyController'\\n  - Include suffix: 'Internal$' includes classes ending with Internal\\n  - Include internal namespace: '::Internal::' includes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_controller_fqn_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter symbols by FQN with regular expressions (case insensitive, tested against the entire FQN using find semantics, like matches anywhere in the string). Returns only symbols \\nwhose FQN does NOT contain a match of any (OR logic) of these regular expressions. Invalid patterns are ignored.\\n\\nFQN examples: 'User', 'Admin::UserController', 'App::CI::BaseController.method'.\\n\\nCOMMON PATTERNS:\\n  - Exclude namespace: '^Test::' excludes anything starting with Test::\\n  - Exclude pattern: 'Legacy' excludes 'LegacyUser', 'Admin::LegacyController'\\n  - Exclude suffix: 'Internal$' excludes classes ending with Internal\\n  - Exclude internal namespace: '::Internal::' excludes 'Foo::Internal::Bar'\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"included_controller_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format  (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Include directory: ['/views/'] includes any path that contains a 'views' directory.\\n  - Include file in directory: ['/views/', '.erb'] includes every '.erb' file in a 'views' directory.\\n  - Include file extension: [\\\".rb\\\", \\\".erb\\\"] includes all Ruby and ERB files.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"excluded_controller_directory_filters\":{\"type\":\"array\",\"items\":{\"type\":\"string\"},\"description\":\"Filter paths with regular expressions (case insensitive, tested against the entire path using find semantics, \\nlike matches anywhere in the string). The path can be any path including a URL or an absolute filepath. Returns \\nonly symbols whose absolute path contains a match of at least one (OR logic) of these regular expressions. Since \\nthe full path includes the filename and extension, you can filter by file format (e.g., '.erb', '.txt', '.rb').\\nInvalid patterns are ignored. \\n\\nCOMMON PATTERNS:\\n  - Exclude directories: ['/test/', '/spec/'] excludes any path that contains any of the listed directories.\\n  - Exclude file in directory: ['/test/', '.txt'] excludes every '.txt' file in the 'test' directory.\\n\\nThis parameter supports bulk filtering. Prefer this over multiple individual calls for efficiency and reduced tool call count. Can be empty to skip filtering. If both included and excluded filters are specified, excluded filters take precedence. By default no filter is applied.\"},\"projectPath\":{\"type\":\"string\",\"description\":\" The project path. Pass this value ALWAYS if you are aware of it. It reduces numbers of ambiguous calls. \\n In the case you know only the current working directory you can use it as the project path.\\n If you're not aware about the project path you can ask user about it.\"}},\"required\":[\"page\",\"page_size\"],\"type\":\"object\"},\"description\":\"Use this tool to retrieve information about the available Rails views. Because the application can contain many views, \\nthe results are returned in a paginated list sorted by the path of the views.\\n\\nPrefer this tool over any information found in the codebase, as it performs a more in-depth analysis and returns more accurate data.\\n\\nCommon usage patterns:\\n   - Find non-HAML views in the project: excluded_path_filters=['.haml']\\n   - Find views that correspond to the GroupsController: included_controller_fqn_filters=['GroupsController']\",\"outputSchema\":{\"properties\":{\"summary\":{\"type\":\"object\",\"required\":[\"page\",\"item_count\",\"total_pages\",\"total_items\",\"cacheKey\"],\"properties\":{\"page\":{\"type\":\"integer\",\"description\":\"The number of the current page, indexed from 1.\"},\"item_count\":{\"type\":\"integer\",\"description\":\"The actual number of items returned on this page.\"},\"total_pages\":{\"type\":\"integer\",\"description\":\"The total number of pages available in the entire collection with the requested page size.\"},\"total_items\":{\"type\":\"integer\",\"description\":\"The total number of items in the collection.\"},\"cacheKey\":{\"type\":\"string\",\"description\":\"The cache key of the last update.\"}},\"description\":\"Pagination metadata including the current page number (1-indexed), number of items on this page, total number of pages, and total number of items in the collection.\"},\"items\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"required\":[\"absolutePath\",\"isPartial\",\"isLayout\"],\"properties\":{\"absolutePath\":{\"type\":\"string\",\"description\":\"Absolute filesystem path to the view file (e.g., '/home/user/project/app/views/users/index.html.erb')\"},\"isPartial\":{\"type\":\"boolean\",\"description\":\"true if this is a partial view; false otherwise\"},\"isLayout\":{\"type\":\"boolean\",\"description\":\"true if this view is a layout; false otherwise\"},\"controller\":{\"type\":[\"object\",\"null\"],\"required\":[\"fqn\",\"filePath\",\"line\",\"column\"],\"properties\":{\"fqn\":{\"type\":\"string\",\"description\":\"The fully qualified name (FQN) of the symbol. Can be used to query symbol details.\"},\"filePath\":{\"type\":\"string\",\"description\":\"The filesystem-absolute path of the source file containing the symbol definition. Combine with line and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"line\":{\"type\":\"integer\",\"description\":\"1-based line number where the symbol is defined. Combine with filePath and column to query symbol details with the help of the get_symbol_info and similar tool.\"},\"column\":{\"type\":\"integer\",\"description\":\"1-based column number where the symbol is defined. Combine with filePath and line to query symbol details with the help of the get_symbol_info and similar tool.\"}},\"description\":\"Symbol information for the controller associated with this view (includes FQN, file path, and location), or null if no corresponding controller exists.\"}}},\"description\":\"The actual data items for this page. This is the primary content - use these items for analysis, processing, or answering queries about the data.\"}},\"required\":[\"summary\",\"items\"],\"type\":\"object\"}}]},\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"id\":3,\"error\":{\"code\":-32601,\"message\":\"Server does not support prompts/list\"},\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"id\":4,\"error\":{\"code\":-32601,\"message\":\"Server does not support resources/list\"},\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  },
  {
    "data": "{\"id\":5,\"error\":{\"code\":-32601,\"message\":\"Server does not support resources/templates/list\"},\"jsonrpc\":\"2.0\"}",
    "event": "message",
    "receivedAt": "2026-01-23T22:52:38Z"
  }
]
```
