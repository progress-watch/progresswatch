# frozen_string_literal: true

module OpenApi
  module CodeSamples
    LANGUAGES = {
      'cli' => 'CLI',
      'curl' => 'curl',
      'javascript' => 'JavaScript',
      'python' => 'Python',
      'php' => 'PHP',
      'ruby' => 'Ruby',
      'java' => 'Java',
      'csharp' => 'C#'
    }.freeze

    # The CLI is not a transport: `progresswatch list` reads a space without naming a URL,
    # so only these can be checked against the document. A command that means the same
    # thing as the request is not guaranteed to exist for every endpoint either, which is
    # why a CLI sample is optional and the tab row is built per operation.
    HTTP_LANGUAGES = (LANGUAGES.keys - ['cli']).freeze

    SAMPLES = {
      'create-space' => {
        'cli' => %(progresswatch space new "Production"),
        'curl' => <<~'TEXT',
          curl -X POST "{{server}}/spaces" \
            -H 'Content-Type: application/json' \
            -d '{"title": "Production", "icon": "🚀"}'
        TEXT
        'javascript' => <<~TEXT,
          const response = await fetch('{{server}}/spaces', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ title: 'Production', icon: '🚀' })
          })

          const { uuid } = await response.json()
        TEXT
        'python' => <<~TEXT,
          import requests

          space = requests.post(
              "{{server}}/spaces",
              json={"title": "Production", "icon": "🚀"},
          ).json()
        TEXT
        'php' => <<~TEXT,
          use GuzzleHttp\\Client;

          $client = new Client(['base_uri' => '{{server}}']);

          $response = $client->post('/spaces', [
              'json' => ['title' => 'Production', 'icon' => '🚀'],
          ]);

          $space = json_decode((string) $response->getBody(), true);
        TEXT
        'ruby' => <<~TEXT,
          require 'faraday'

          conn = Faraday.new('{{server}}') do |f|
            f.request :json
            f.response :json
          end

          space = conn.post('/spaces', { title: 'Production', icon: '🚀' }).body
        TEXT
        'java' => <<~TEXT,
          var client = HttpClient.newHttpClient();

          var request = HttpRequest.newBuilder()
              .uri(URI.create("{{server}}/spaces"))
              .header("Content-Type", "application/json")
              .POST(HttpRequest.BodyPublishers.ofString("""
                  {"title": "Production", "icon": "🚀"}"""))
              .build();

          var response = client.send(request, HttpResponse.BodyHandlers.ofString());
        TEXT
        'csharp' => <<~TEXT
          using System.Net.Http.Json;

          var client = new HttpClient { BaseAddress = new Uri("{{server}}") };

          var response = await client.PostAsJsonAsync("/spaces", new
          {
              title = "Production",
              icon = "🚀"
          });

          var space = await response.Content.ReadFromJsonAsync<JsonElement>();
        TEXT
      },

      'create-task' => {
        'cli' => %(TASK=$(progresswatch new "Crawl docs" --source crawler.py)),
        'curl' => <<~'TEXT',
          curl -X POST "{{server}}/spaces/$SPACE_UUID/tasks" \
            -H 'Content-Type: application/json' \
            -d '{"title": "Crawl docs", "source": "crawler.py"}'
        TEXT
        'javascript' => <<~TEXT,
          const response = await fetch(`{{server}}/spaces/${spaceUuid}/tasks`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ title: 'Crawl docs', source: 'crawler.py' })
          })

          const { uuid } = await response.json()
        TEXT
        'python' => <<~TEXT,
          import requests

          task = requests.post(
              f"{{server}}/spaces/{space_uuid}/tasks",
              json={"title": "Crawl docs", "source": "crawler.py"},
          ).json()
        TEXT
        'php' => <<~TEXT,
          use GuzzleHttp\\Client;

          $client = new Client(['base_uri' => '{{server}}']);

          $response = $client->post("/spaces/{$spaceUuid}/tasks", [
              'json' => ['title' => 'Crawl docs', 'source' => 'crawler.py'],
          ]);

          $task = json_decode((string) $response->getBody(), true);
        TEXT
        'ruby' => <<~'TEXT',
          require 'faraday'

          conn = Faraday.new('{{server}}') do |f|
            f.request :json
            f.response :json
          end

          task = conn.post("/spaces/#{space_uuid}/tasks", { title: 'Crawl docs', source: 'crawler.py' }).body
        TEXT
        'java' => <<~TEXT,
          var client = HttpClient.newHttpClient();

          var request = HttpRequest.newBuilder()
              .uri(URI.create("{{server}}/spaces/" + spaceUuid + "/tasks"))
              .header("Content-Type", "application/json")
              .POST(HttpRequest.BodyPublishers.ofString("""
                  {"title": "Crawl docs", "source": "crawler.py"}"""))
              .build();

          var response = client.send(request, HttpResponse.BodyHandlers.ofString());
        TEXT
        'csharp' => <<~TEXT
          using System.Net.Http.Json;

          var client = new HttpClient { BaseAddress = new Uri("{{server}}") };

          var response = await client.PostAsJsonAsync($"/spaces/{spaceUuid}/tasks", new
          {
              title = "Crawl docs",
              source = "crawler.py"
          });

          var task = await response.Content.ReadFromJsonAsync<JsonElement>();
        TEXT
      },

      'report-progress' => {
        'cli' => %(progresswatch update $TASK --current 1200 --end 50000 --values pages=1200 --values errors=3),
        'curl' => <<~'TEXT',
          curl -X PUT "{{server}}/tasks/$TASK" \
            -H 'Content-Type: application/json' \
            -d '{"current": 1200, "end": 50000, "values": {"pages": 1200, "errors": 3}}'
        TEXT
        'javascript' => <<~TEXT,
          await fetch(`{{server}}/tasks/${task}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              current: 1200,
              end: 50000,
              values: { pages: 1200, errors: 3 }
            })
          })
        TEXT
        'python' => <<~TEXT,
          import requests

          requests.put(
              f"{{server}}/tasks/{task}",
              json={"current": 1200, "end": 50000, "values": {"pages": 1200, "errors": 3}},
          )
        TEXT
        'php' => <<~TEXT,
          use GuzzleHttp\\Client;

          $client = new Client(['base_uri' => '{{server}}']);

          $client->put("/tasks/{$task}", [
              'json' => [
                  'current' => 1200,
                  'end' => 50000,
                  'values' => ['pages' => 1200, 'errors' => 3],
              ],
          ]);
        TEXT
        'ruby' => <<~'TEXT',
          require 'faraday'

          conn = Faraday.new('{{server}}') { |f| f.request :json }

          conn.put("/tasks/#{task}", { current: 1200, end: 50_000, values: { pages: 1200, errors: 3 } })
        TEXT
        'java' => <<~TEXT,
          var client = HttpClient.newHttpClient();

          var request = HttpRequest.newBuilder()
              .uri(URI.create("{{server}}/tasks/" + task))
              .header("Content-Type", "application/json")
              .PUT(HttpRequest.BodyPublishers.ofString("""
                  {"current": 1200, "end": 50000, "values": {"pages": 1200, "errors": 3}}"""))
              .build();

          client.send(request, HttpResponse.BodyHandlers.ofString());
        TEXT
        'csharp' => <<~TEXT
          using System.Net.Http.Json;

          var client = new HttpClient { BaseAddress = new Uri("{{server}}") };

          await client.PutAsJsonAsync($"/tasks/{task}", new
          {
              current = 1200,
              end = 50000,
              values = new { pages = 1200, errors = 3 }
          });
        TEXT
      },

      'get-space' => {
        'cli' => %(progresswatch list --json),
        'curl' => %(curl "{{server}}/spaces/$SPACE_UUID"),
        'javascript' => <<~TEXT,
          const space = await fetch(`{{server}}/spaces/${spaceUuid}`).then((response) => response.json())
        TEXT
        'python' => <<~TEXT,
          import requests

          space = requests.get(f"{{server}}/spaces/{space_uuid}").json()
        TEXT
        'php' => <<~TEXT,
          use GuzzleHttp\\Client;

          $client = new Client(['base_uri' => '{{server}}']);

          $space = json_decode((string) $client->get("/spaces/{$spaceUuid}")->getBody(), true);
        TEXT
        'ruby' => <<~'TEXT',
          require 'faraday'

          conn = Faraday.new('{{server}}') { |f| f.response :json }

          space = conn.get("/spaces/#{space_uuid}").body
        TEXT
        'java' => <<~TEXT,
          var client = HttpClient.newHttpClient();

          var request = HttpRequest.newBuilder()
              .uri(URI.create("{{server}}/spaces/" + spaceUuid))
              .build();

          var response = client.send(request, HttpResponse.BodyHandlers.ofString());
        TEXT
        'csharp' => <<~TEXT
          using System.Net.Http.Json;

          var client = new HttpClient { BaseAddress = new Uri("{{server}}") };

          var space = await client.GetFromJsonAsync<JsonElement>($"/spaces/{spaceUuid}");
        TEXT
      },

      'get-task' => {
        'cli' => %(progresswatch show $TASK --json),
        'curl' => %(curl "{{server}}/tasks/$TASK"),
        'javascript' => <<~TEXT,
          const task = await fetch(`{{server}}/tasks/${taskUuid}`).then((response) => response.json())
        TEXT
        'python' => <<~TEXT,
          import requests

          task = requests.get(f"{{server}}/tasks/{task_uuid}").json()
        TEXT
        'php' => <<~TEXT,
          use GuzzleHttp\\Client;

          $client = new Client(['base_uri' => '{{server}}']);

          $task = json_decode((string) $client->get("/tasks/{$taskUuid}")->getBody(), true);
        TEXT
        'ruby' => <<~'TEXT',
          require 'faraday'

          conn = Faraday.new('{{server}}') { |f| f.response :json }

          task = conn.get("/tasks/#{task_uuid}").body
        TEXT
        'java' => <<~TEXT,
          var client = HttpClient.newHttpClient();

          var request = HttpRequest.newBuilder()
              .uri(URI.create("{{server}}/tasks/" + taskUuid))
              .build();

          var response = client.send(request, HttpResponse.BodyHandlers.ofString());
        TEXT
        'csharp' => <<~TEXT
          using System.Net.Http.Json;

          var client = new HttpClient { BaseAddress = new Uri("{{server}}") };

          var task = await client.GetFromJsonAsync<JsonElement>($"/tasks/{taskUuid}");
        TEXT
      },

      'health' => {
        'cli' => %(progresswatch status),
        'curl' => %(curl "{{server}}/up"),
        'javascript' => %(const health = await fetch('{{server}}/up').then((response) => response.json())),
        'python' => <<~TEXT,
          import requests

          health = requests.get("{{server}}/up").json()
        TEXT
        'php' => <<~TEXT,
          use GuzzleHttp\\Client;

          $health = json_decode((string) (new Client())->get('{{server}}/up')->getBody(), true);
        TEXT
        'ruby' => <<~TEXT,
          require 'faraday'

          health = Faraday.new { |f| f.response :json }.get('{{server}}/up').body
        TEXT
        'java' => <<~TEXT,
          var client = HttpClient.newHttpClient();

          var request = HttpRequest.newBuilder().uri(URI.create("{{server}}/up")).build();

          var response = client.send(request, HttpResponse.BodyHandlers.ofString());
        TEXT
        'csharp' => <<~TEXT
          using System.Net.Http.Json;

          var client = new HttpClient();

          var health = await client.GetFromJsonAsync<JsonElement>("{{server}}/up");
        TEXT
      }
    }.freeze

    module_function

    def call(operation, base_url:)
      SAMPLES.fetch(operation[:id], {}).transform_values { |code| code.strip.gsub('{{server}}', base_url) }
    end
  end
end
