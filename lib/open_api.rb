# frozen_string_literal: true

# The JSON API as an OpenAPI 3.1 document. Hand-written, like the sitemap, and specced
# against the routes and the serializers so it cannot quietly drift from them.
#
# 3.1, not 3.0, because its schemas are JSON Schema 2020-12: a nullable field is
# `type: [x, "null"]` rather than 3.0's bolted-on `nullable: true`, and almost every
# field here is nullable.
#
# It is one literal on purpose, repetition included. Factoring the repeated shapes into
# helpers made it shorter and made it impossible to read one endpoint without assembling
# it from four definitions, which is the one thing a reference has to allow.
#
# MCP is not in it. `/mcp` speaks JSON-RPC over one POST, which OpenAPI describes as
# "a POST that takes an object" — true and useless. It is documented where it is used.
#
# There is no `securitySchemes`, and linters flag that. OpenAPI can describe a header, a
# cookie or a query parameter as a credential, but not a path segment, and ours is the
# uuid in the path. Inventing a scheme to quiet the warning would describe an API we do
# not serve.
module OpenApi
  DESCRIPTION = <<~TEXT
    Report progress from anything that runs without a screen.

    There are no accounts. A space UUID is the credential: whoever has it can read and
    write that space, and nothing on the server can recover it once lost.

    Progress lives in memory and expires on inactivity. It is never written to the
    database, so there is no history to read back — only what is happening now.

    Every write to a task replaces its whole state. Anything omitted is cleared, not
    kept; the process doing the work always knows its own state, so sending all of it
    each time is simpler than tracking what was already sent.

    The server also speaks MCP at POST /mcp, which is JSON-RPC and not described here.
  TEXT

  PATHS = {
    '/spaces' => {
      'post' => {
        'operationId' => 'createSpace',
        'summary' => 'Create a space',
        'description' => 'The response carries the only copy of the uuid. Keep it like an API token.',
        'requestBody' => {
          'required' => true,
          'content' => {
            'application/json' => {
              'schema' => {
                'type' => 'object',
                'properties' => {
                  'title' => { 'type' => %w[string null] },
                  'icon' => {
                    'type' => 'string',
                    'description' => 'One character; an emoji reads best.'
                  }
                }
              }
            }
          }
        },
        'responses' => {
          '201' => {
            'description' => 'Created',
            'content' => {
              'application/json' => {
                'schema' => {
                  'type' => 'object',
                  'properties' => {
                    'uuid' => { 'type' => 'string' },
                    'title' => { 'type' => %w[string null] },
                    'icon' => { 'type' => %w[string null] }
                  },
                  'required' => %w[uuid title icon]
                }
              }
            }
          },
          '422' => {
            'description' => 'Icon was more than one character',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          }
        }
      }
    },
    '/spaces/{space_uuid}' => {
      'get' => {
        'operationId' => 'getSpace',
        'summary' => 'Read a space and every task in it',
        'description' => 'One query and one Redis MGET whatever the task count. Safe to poll every few seconds.',
        'parameters' => [
          {
            'name' => 'space_uuid',
            'in' => 'path',
            'required' => true,
            'schema' => {
              'type' => 'string',
              'format' => 'uuid'
            }
          }
        ],
        'responses' => {
          '200' => {
            'description' => 'The space',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Space' } } }
          },
          '404' => {
            'description' => 'No such space, or the uuid is wrong',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          }
        }
      }
    },
    '/spaces/{space_uuid}/tasks' => {
      'post' => {
        'operationId' => 'createTask',
        'summary' => 'Create a task',
        'parameters' => [
          {
            'name' => 'space_uuid',
            'in' => 'path',
            'required' => true,
            'schema' => {
              'type' => 'string',
              'format' => 'uuid'
            }
          }
        ],
        'requestBody' => {
          'required' => true,
          'content' => {
            'application/json' => {
              'schema' => {
                'type' => 'object',
                'properties' => {
                  'title' => { 'type' => 'string' },
                  'source' => {
                    'type' => 'string',
                    'description' => 'What is reporting, e.g. crawler.py'
                  },
                  'parent_uuid' => {
                    'type' => 'string',
                    'description' => 'A step of an existing task. One level only.'
                  }
                }
              }
            }
          }
        },
        'responses' => {
          '201' => {
            'description' => 'Created',
            'content' => {
              'application/json' => {
                'schema' => {
                  'type' => 'object',
                  'properties' => { 'uuid' => { 'type' => 'string' } },
                  'required' => ['uuid']
                }
              }
            }
          },
          '404' => {
            'description' => 'No such space',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          },
          '422' => {
            'description' => 'parent_uuid is unknown, is already a child, or belongs to another space',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          }
        }
      }
    },
    '/tasks/{task_uuid}' => {
      'get' => {
        'operationId' => 'getTask',
        'summary' => 'Read one task and its children',
        'parameters' => [
          {
            'name' => 'task_uuid',
            'in' => 'path',
            'required' => true,
            'schema' => {
              'type' => 'string',
              'format' => 'uuid'
            }
          }
        ],
        'responses' => {
          '200' => {
            'description' => 'The task',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Task' } } }
          },
          '404' => {
            'description' => 'No such task',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          }
        }
      },
      'put' => {
        'operationId' => 'reportProgress',
        'summary' => 'Report progress',
        'description' => 'Replaces the whole state. Omitting `values` clears it. Completing is one-way: it ' \
                         'happens when `current` reaches a positive `end` or when `done` is true, sends the ' \
                         'notification once, and later writes do not move the finish time.',
        'parameters' => [
          {
            'name' => 'task_uuid',
            'in' => 'path',
            'required' => true,
            'schema' => {
              'type' => 'string',
              'format' => 'uuid'
            }
          }
        ],
        'requestBody' => {
          'required' => true,
          'content' => {
            'application/json' => {
              'schema' => {
                'type' => 'object',
                'properties' => {
                  'current' => {
                    'type' => 'number',
                    'description' => 'A count, not a percentage.'
                  },
                  'end' => {
                    'type' => 'number',
                    'description' => 'May change between calls.'
                  },
                  'values' => {
                    'type' => 'object',
                    'additionalProperties' => true
                  },
                  'done' => { 'type' => 'boolean' }
                }
              }
            }
          }
        },
        'responses' => {
          '200' => {
            'description' => 'The task as it now stands',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Task' } } }
          },
          '400' => {
            'description' => 'values was not a flat object of numbers, strings or booleans',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          },
          '404' => {
            'description' => 'No such task',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          }
        }
      },
      'patch' => {
        'operationId' => 'reportProgressPatch',
        'summary' => 'Rejected',
        'description' => 'PATCH promises a merge and a write here replaces everything, so it is refused ' \
                         'rather than quietly doing something else. Use PUT.',
        'parameters' => [
          {
            'name' => 'task_uuid',
            'in' => 'path',
            'required' => true,
            'schema' => {
              'type' => 'string',
              'format' => 'uuid'
            }
          }
        ],
        'responses' => {
          '405' => {
            'description' => 'Use PUT',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          }
        }
      }
    },
    '/up' => {
      'get' => {
        'operationId' => 'health',
        'summary' => 'Health check',
        'description' => 'Checks its dependencies, so a container with a dead Redis fails it.',
        'responses' => {
          '200' => {
            'description' => 'Healthy',
            'content' => { 'application/json' => { 'schema' => { 'type' => 'object' } } }
          },
          '503' => {
            'description' => 'A dependency is down',
            'content' => { 'application/json' => { 'schema' => { 'type' => 'object' } } }
          }
        }
      }
    }
  }.freeze

  module_function

  # rubocop:disable Metrics/MethodLength -- the length is the document, not the logic
  def call(base_url:)
    {
      'openapi' => '3.1.0',
      'info' => {
        'title' => 'Progress Watch',
        'version' => '1',
        'description' => DESCRIPTION,
        'license' => {
          'name' => 'AGPL-3.0-only',
          'identifier' => 'AGPL-3.0-only'
        }
      },
      'servers' => [{ 'url' => base_url }],
      'paths' => PATHS,
      'components' => {
        'schemas' => {
          'Space' => {
            'type' => 'object',
            'properties' => {
              'uuid' => { 'type' => 'string' },
              'title' => { 'type' => %w[string null] },
              'icon' => {
                'type' => %w[string null],
                'description' => 'One character. Counted in grapheme clusters.'
              },
              'tasks' => {
                'type' => 'array',
                'items' => { '$ref' => '#/components/schemas/Task' },
                'description' => 'Top-level tasks, each with its children nested.'
              }
            },
            'required' => %w[uuid title icon tasks]
          },
          'Task' => {
            'type' => 'object',
            'properties' => {
              'uuid' => { 'type' => 'string' },
              'space_uuid' => { 'type' => 'string' },
              'parent_uuid' => { 'type' => %w[string null] },
              'title' => { 'type' => %w[string null] },
              'source' => { 'type' => %w[string null] },
              'created_at' => {
                'type' => 'string',
                'format' => 'date-time'
              },
              'finished_at' => {
                'type' => %w[string null],
                'format' => 'date-time'
              },
              'duration' => {
                'type' => %w[integer null],
                'description' => 'Seconds, set once when the task completes.'
              },
              'progress' => { '$ref' => '#/components/schemas/Progress' },
              'children' => {
                'type' => 'array',
                'items' => { '$ref' => '#/components/schemas/Task' },
                'description' => 'One level only. A child is always empty here.'
              }
            },
            'required' => %w[uuid space_uuid parent_uuid title source created_at finished_at duration progress children]
          },
          'Progress' => {
            'type' => %w[object null],
            'description' => 'Live state, held in memory and expired on inactivity. Null means the task exists ' \
                             'but has never reported, which is not the same as reporting zero.',
            'properties' => {
              'current' => { 'type' => %w[number null] },
              'end' => { 'type' => %w[number null] },
              'ratio' => {
                'type' => %w[number null],
                'minimum' => 0,
                'maximum' => 1,
                'description' => 'Null when `end` is zero or missing: an unknown denominator, not zero progress.'
              },
              'values' => {
                'type' => 'object',
                'additionalProperties' => true,
                'description' => 'Flat extras. A `log` key holds one line, the latest, never a history.'
              },
              'updated_at' => { 'type' => %w[string null] },
              'aggregated' => {
                'type' => 'boolean',
                'description' => 'True on a parent, whose numbers count its finished children.'
              }
            },
            'required' => %w[current end ratio values updated_at aggregated]
          },
          'Error' => {
            'type' => 'object',
            'properties' => { 'error' => { 'type' => 'string' } },
            'required' => ['error']
          }
        }
      }
    }
  end
  # rubocop:enable Metrics/MethodLength
end
