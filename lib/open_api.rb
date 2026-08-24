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
              },
              'example' => { 'title' => 'Production', 'icon' => '🚀' }
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
        'description' => 'Returns every task by default. Tasks and their children come back in creation order, ' \
                         'oldest first; any other order is a display decision and belongs to the client. ' \
                         'A space that has run for months is worth paging through — see the three parameters below.',
        'parameters' => [
          {
            'name' => 'space_uuid',
            'in' => 'path',
            'required' => true,
            'schema' => {
              'type' => 'string',
              'format' => 'uuid'
            }
          },
          {
            'name' => 'limit',
            'in' => 'query',
            'required' => false,
            'description' => 'How many top-level tasks to return. Counts back from the newest, so a bare limit ' \
                             'gives the recent end of the space rather than its oldest rows. Children never ' \
                             'count against it and are never cut off.',
            'schema' => { 'type' => 'integer', 'minimum' => 1 }
          },
          {
            'name' => 'before',
            'in' => 'query',
            'required' => false,
            'description' => 'Only tasks created strictly before this instant, newest first, for walking back ' \
                             'through history. Pass the created_at of the oldest task you hold; it round-trips ' \
                             'exactly and is never returned again.',
            'schema' => { 'type' => 'string', 'format' => 'date-time' }
          },
          {
            'name' => 'after',
            'in' => 'query',
            'required' => false,
            'description' => 'Only tasks created strictly after this instant, oldest first, for asking what is ' \
                             'new. Pass the created_at of the newest task you hold.',
            'schema' => { 'type' => 'string', 'format' => 'date-time' }
          }
        ],
        'responses' => {
          '200' => {
            'description' => 'The space',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Space' } } }
          },
          '400' => {
            'description' => 'A cursor that is not a timestamp, or a limit that is not a whole number',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
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
        'description' => 'The returned uuid is the only handle on the task. Until something reports against it ' \
                         'the task reads as waiting for data, which looks the same as a reporter that died — so ' \
                         'write to it when the work starts, even with nothing to count.',
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
              },
              'example' => { 'title' => 'Crawl docs', 'source' => 'crawler.py' }
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
        'description' => 'The same shape as one entry in a space, steps nested. Cheaper to poll than the whole ' \
                         'space when only one thing is running.',
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
                         'notification once, and later writes do not move the finish time. A body of just ' \
                         '`{"done": true}` is the exception to the overwrite: it closes the task and keeps ' \
                         'the last numbers reported, so a finished task still shows what it counted.',
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
                    'description' => 'May change between calls. Omit it for a count with no total: `current` ' \
                                     'rises, `ratio` stays null, and the task reads as a counter rather than a bar.'
                  },
                  'values' => {
                    'type' => 'object',
                    'additionalProperties' => true
                  },
                  'done' => {
                    'type' => 'boolean',
                    'description' => 'Finish the task. Send it alone to keep the last numbers; send it ' \
                                     'beside a count and the usual overwrite applies.'
                  }
                }
              },
              'example' => {
                'current' => 1200,
                'end' => 50_000,
                'values' => { 'pages' => 1200, 'errors' => 3 }
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
        'deprecated' => true,
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
    '/tasks/{task_uuid}/report' => {
      'get' => {
        'operationId' => 'reportProgressFromUrl',
        'summary' => 'Report progress from a URL',
        'description' => 'The same write as PUT, reachable by anything that can only fire a URL: an uptime ' \
                         'pinger, a webhook field in somebody else\'s product, a device, a cron line with a bare ' \
                         'curl. If your client can send a request body, use PUT instead. This one is a GET that ' \
                         'writes, so anything that follows the URL performs the write — a link unfurler in a chat ' \
                         'app will report on your behalf. Keep it out of anywhere a machine might click it.',
        'parameters' => [
          {
            'name' => 'task_uuid',
            'in' => 'path',
            'required' => true,
            'schema' => { 'type' => 'string', 'format' => 'uuid' }
          },
          {
            'name' => 'current',
            'in' => 'query',
            'description' => 'A count, not a percentage.',
            'schema' => { 'type' => 'number' }
          },
          {
            'name' => 'end',
            'in' => 'query',
            'description' => 'May change between calls. Omit it for a count with no total.',
            'schema' => { 'type' => 'number' }
          },
          {
            'name' => 'done',
            'in' => 'query',
            'description' => 'Finish the task. Alone, it keeps the last numbers reported. It also finishes ' \
                             'on its own once current reaches end.',
            'schema' => { 'type' => 'boolean' }
          },
          {
            'name' => 'values',
            'in' => 'query',
            'style' => 'deepObject',
            'explode' => true,
            'description' => 'Flat extras, as values[pages]=1200. They arrive as text, since a query string ' \
                             'carries no types.',
            'schema' => { 'type' => 'object', 'additionalProperties' => true }
          }
        ],
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
      }
    },
    '/up' => {
      'get' => {
        'operationId' => 'health',
        'summary' => 'Health check',
        'description' => 'Checks its dependencies, so a container with a dead Redis fails it. The worker is ' \
                         'reported too, and a dead one does not fail the check.',
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

  SCHEMAS = {
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
      'description' => 'Live state, held in memory and expired on inactivity. Null means the task is ' \
                       'unfinished and has never reported, which is not the same as reporting zero. ' \
                       'A finished task always has an object, whether or not it ever reported.',
      'properties' => {
        'current' => { 'type' => %w[number null] },
        'end' => { 'type' => %w[number null] },
        'ratio' => {
          'type' => %w[number null],
          'minimum' => 0,
          'maximum' => 1,
          'description' => '1 once the task is finished, whatever the counts say. Otherwise null when ' \
                           '`end` is zero or missing: an unknown denominator, not zero progress.'
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
  }.freeze

  # -- the length is the document, not the logic
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
        'schemas' => SCHEMAS
      }
    }
  end
end
