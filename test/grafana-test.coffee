Helper = require('hubot-test-helper')
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
nock = require('nock')

helper = new Helper('./../src/grafana.coffee')

expect = chai.expect

before ->
  matchesBlanket = (path) -> path.match /node_modules\/blanket/
  runningTestCoverage = Object.keys(require.cache).filter(matchesBlanket).length > 0
  if runningTestCoverage
    require('require-dir')("#{__dirname}/../src", {recurse: true, duplicates: true})

describe 'grafana v4 and below', ->
  room = null

  beforeEach ->
    process.env.HUBOT_GRAFANA_HOST = 'http://play.grafana.org'
    room = helper.createRoom()
    do nock.disableNetConnect

    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/grafana')(@robot)

  afterEach ->
    room.destroy()
    nock.cleanAll()
    delete process.env.HUBOT_GRAFANA_HOST

  context 'ensure all listeners are registered', ->
    it 'registers a dashboard listener', ->
      expect(@robot.respond).to.have.been.calledWith(/(?:grafana|graph|graf) (?:dash|dashboard|db) ([A-Za-z0-9\-\:_]+)(.*)?/i)

    it 'registers a list listener', ->
      expect(@robot.respond).to.have.been.calledWith(/(?:grafana|graph|graf) list\s?(.+)?/i)

    it 'registers a search listener', ->
      expect(@robot.respond).to.have.been.calledWith(/(?:grafana|graph|graf) search (.+)/i)

  context 'ask hubot to list dashboards', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/search?type=dash-db')
        .replyWithFile(200, __dirname + '/fixtures/search-v4.json')
      room.user.say 'alice', 'hubot graf list'
      setTimeout done, 100

    it 'hubot should respond with a list of dashboards', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf list' ]
        [ 'hubot', "Available dashboards:\n- annotations: Annotations\n- big-dashboard: Big Dashboard\n- big-dashboard2: Big Dashboard2\n- elasticsearch-metrics: Elasticsearch Metrics\n- grafana-play-home: Grafana Play Home\n- graph-styles: Graph styles\n- graphite-carbon-metrics: Graphite Carbon Metrics\n- graphite-template-screencast: Graphite Template Screencast\n- influxdb: InfluxDB\n- influxdb-templated-queries: InfluxDB Templated Queries\n- issue-3275: Issue 3275\n- light-theme: Light theme\n- litmus-endpoint-web: Litmus Endpoint: |--- Web\n- matt_test_instance: Matt_Test_Instance\n- my-first-dashboard: My First Dashboard\n- new-dashboard: New dashboard\n- new-features-in-v1-8: New features in v1.8\n- new-features-in-v19: New features in v1.9\n- new-features-in-v20: New features in v2.0\n- new-features-in-v2-1: New features in v2.1\n- perftest: PerfTest\n- rogue: Rogue\n- stats: Stats\n- stats-ds: Stats DS\n- stats-trends: Stats trends\n- temp-dashboard-graphite-threshold-func: Temp dashboard graphite threshold func\n- templated-graphs: Templated Graphs\n- templated-graphs-nested: Templated Graphs Nested\n- test: Test\n- test-slides: Test Slides\n- ultimate-graphite-query-guide: Ultimate Graphite Query Guide\n- loadbalancers: loadbalancers\n- singlestat-rounding-threshold: singlestat rounding threshold\n"]
      ]

  context 'ask hubot to list dashboards filterd by tag', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/search?type=dash-db&tag=demo')
        .replyWithFile(200, __dirname + '/fixtures/search-tag-v4.json')
      room.user.say 'alice', 'hubot graf list demo'
      setTimeout done, 100

    it 'hubot should respond with a list of dashboards with tag', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf list demo' ]
        [ 'hubot', "Dashboards tagged `demo`:\n- annotations: Annotations\n- graph-styles: Graph styles\n- new-features-in-v19: New features in v1.9\n- new-features-in-v20: New features in v2.0\n- new-features-in-v2-1: New features in v2.1\n"]
      ]

  context 'ask hubot to search dashboards', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/search?type=dash-db&query=elasticsearch')
        .replyWithFile(200, __dirname + '/fixtures/search-query-v4.json')
      room.user.say 'alice', 'hubot graf search elasticsearch'
      setTimeout done, 100

    it 'hubot should respond with a matching dashboard', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf search elasticsearch' ]
        [ 'hubot', "Dashboards matching `elasticsearch`:\n- elasticsearch-metrics: Elasticsearch Metrics\n"]
      ]

  context 'ask hubot to return a specific panel by API ID', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v4.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:panel-8'
      setTimeout done, 100

    it 'hubot should respond with a matching dashboard', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:panel-8' ]
        [ 'hubot', "Graphite examples: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=1000&height=500&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot to return a specific panel by visual ID', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v4.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3'
      setTimeout done, 100

    it 'hubot should respond with a matching dashboard', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3' ]
        [ 'hubot', "Graphite examples: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=1000&height=500&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot to return different default image sizes', ->
    beforeEach (done) ->
      process.env.HUBOT_GRAFANA_DEFAULT_WIDTH = 1024
      process.env.HUBOT_GRAFANA_DEFAULT_HEIGHT = 768
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v4.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3'
      setTimeout done, 100
    afterEach ->
      delete process.env.HUBOT_GRAFANA_DEFAULT_WIDTH
      delete process.env.HUBOT_GRAFANA_DEFAULT_HEIGHT

    it 'hubot should respond with the custom image size set in environment', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3' ]
        [ 'hubot', "Graphite examples: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=1024&height=768&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot to return a specific panel with a custom size', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v4.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3 width=2500 height=700'
      setTimeout done, 100

    it 'hubot should respond with a resized image specified in request', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3 width=2500 height=700' ]
        [ 'hubot', "Graphite examples: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=2500&height=700&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]
  context 'ask hubot to return a specific panel with a custom size in any order', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v4.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3 height=700 width=2500'
      setTimeout done, 100

    it 'hubot should respond with a resized image specified in request', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3 height=700 width=2500' ]
        [ 'hubot', "Graphite examples: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=2500&height=700&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot for templated dashboard', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/monitoring-default')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-monitoring-default-v4.json')
      room.user.say 'alice', 'hubot graf db monitoring-default:network server=ww3.example.com now-6h'
      setTimeout done, 100

    it 'hubot should respond with a templated graph', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db monitoring-default:network server=ww3.example.com now-6h' ]
        [ 'hubot', 'ww3.example.com network: http://play.grafana.org/render/dashboard-solo/db/monitoring-default/?panelId=7&width=1000&height=500&from=now-6h&to=now&var-server=ww3.example.com - http://play.grafana.org/dashboard/db/monitoring-default/?panelId=7&fullscreen&from=now-6h&to=now&var-server=ww3.example.com' ]
      ]

describe 'grafana v5', ->
  room = null

  beforeEach ->
    process.env.HUBOT_GRAFANA_HOST = 'http://play.grafana.org'
    room = helper.createRoom()
    do nock.disableNetConnect

    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/grafana')(@robot)

  afterEach ->
    room.destroy()
    nock.cleanAll()
    delete process.env.HUBOT_GRAFANA_HOST

  context 'ensure all listeners are registered', ->
    it 'registers a dashboard listener', ->
      expect(@robot.respond).to.have.been.calledWith(/(?:grafana|graph|graf) (?:dash|dashboard|db) ([A-Za-z0-9\-\:_]+)(.*)?/i)

    it 'registers a list listener', ->
      expect(@robot.respond).to.have.been.calledWith(/(?:grafana|graph|graf) list\s?(.+)?/i)

    it 'registers a search listener', ->
      expect(@robot.respond).to.have.been.calledWith(/(?:grafana|graph|graf) search (.+)/i)

  context 'ask hubot to list dashboards', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/search?type=dash-db')
        .replyWithFile(200, __dirname + '/fixtures/search-v5.json')
      room.user.say 'alice', 'hubot graf list'
      setTimeout done, 100

    it 'hubot should respond with a list of dashboards', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf list' ]
        [ 'hubot', "Available dashboards:\n- 1-promcon-dashboard: 1. Promcon dashboard\n- 2-promcon-annotations: 2. Promcon annotations\n- 4-years-of-grafana: 4 Years Of Grafana\n- advanced-layout: Advanced Layout\n- alerting: Alerting\n- alerting-flappy: Alerting flappy\n- alerting-list-issue: Alerting List Issue\n- annotations: Annotations\n- annotations-graphite: Annotations Graphite\n- annotations-image: Annotations Image\n- apache-overview2: Apache Overview2\n- at-symbol-in-title: at symbol in title\n- big-dashboard: Big Dashboard\n- big-dashboard-theme: Big Dashboard Theme\n- big-dashboard2: Big Dashboard2\n- business-metrics: Business Metrics\n- celcius: Celcius\n- custom-templated-query: Custom Templated query\n- dashboard-links-issue: Dashboard Links Issue\n- dashboard-with-panel-link: Dashboard with panel link\n- dashboard-with-dash: Dashboard-with-dash\n- elastic-90th-percentile: Elastic 90th percentile\n- elasticsearch-derivative: Elasticsearch Derivative\n- elasticsearch-metrics: Elasticsearch Metrics\n- elasticsearch-metrics-filter: Elasticsearch Metrics Filter\n- elasticsearch-query-filter: Elasticsearch query filter\n- elasticsearch-templated: Elasticsearch Templated\n- elasticsearch-templated-fields: Elasticsearch Templated Fields\n- empty: Empty\n- fill-below-to: Fill below to\n- github: Github\n- github-monitorama-stats: Github Monitorama Stats\n- github-repo-trends-comments: Github Repo Trends Comments\n- github-repo-trends-issues: Github Repo Trends Issues\n- grafana-demo: Grafana demo\n- grafana-issue: Grafana issue\n- grafana-play-home: Grafana Play Home\n- grafana-play-home2: Grafana Play Home2\n- grafana-trend: Grafana Trend\n- grafana-versions: Grafana versions\n- grafanacon-wifi: GrafanaCon Wifi\n- graph-styles: Graph styles\n- graphite-carbon-metrics: Graphite Carbon Metrics\n- graphite-panel-repeats-copy: Graphite panel repeats Copy\n- graphite-panel-repeats-hidden: Graphite panel repeats hidden\n- graphite-sumseries-aliasbynode: Graphite sumSeries AliasByNode\n- graphite-templated-nested: Graphite Templated Nested\n- graphite-templated-nested-copy: Graphite Templated Nested Copy\n- graphite-templated-nested-simple: Graphite Templated Nested simple\n- group-by-node: group by node\n- ignite: Ignite\n- image-test: Image test\n- influxdb-annotations: InfluxDB Annotations\n- influxdb-default-fill-value: Influxdb default fill value\n- influxdb-group-by-count: InfluxDB group by count\n- influxdb-group-by-time: InfluxDB Group By Time\n- influxdb-group-by-variable: InfluxDB Group By Variable\n- influxdb-issue-4204: InfluxDB Issue #4204\n- influxdb-issue-5544: InfluxDB Issue #5544\n- influxdb-raw-query-template-var: InfluxDB Raw Query  Template Var\n- influxdb-table: InfluxDB Table\n- influxdb-templated-queries: InfluxDB Templated Queries\n- influxdb-templated-queries-copy: InfluxDB Templated Queries Copy\n- influxdb-templating-example2: InfluxDB templating example2\n- internal-grafana-stats: Internal Grafana Stats\n- issue-5214: Issue #5214\n- issue-6200: Issue #6200\n- issue-4164: Issue 4164\n- issue-5599: Issue 5599\n- issue-6320: Issue 6320\n- layout-test: Layout test\n- lazy-loading: Lazy Loading\n- lazy-loading-2: Lazy Loading 2\n- legend: Legend\n- legend-colors: Legend colors\n- link-using-template-variable: Link using template variable\n- logarithmic-scales: Logarithmic scales\n- manual-entry: Manual Entry\n- mixed-datasources: Mixed Datasources\n- mixing-panels-without-legend: Mixing panels without legend\n- monitorama-es-graphite: Monitorama - ES + Graphite\n- monitorama-templating: Monitorama Templating\n- monitorama-wifi: Monitorama Wifi\n- monitorama-shall-we-play-a-game: Monitorama: Shall We Play a Game?\n- new-dashboard-copy: New dashboard Copy\n- new-dashboard-for-demo: New dashboard for demo\n- new-dashboard-with-alert: New Dashboard With Alert\n- new-features-in-v4-3: New Features in  v4.3\n- new-features-in-v1-8: New features in v1.8\n- new-features-in-v1-9: New features in v1.9\n- new-features-in-v2-0: New features in v2.0\n- new-features-in-v2-1: New features in v2.1\n- new-features-in-v2-6: New features in v2.6\n- new-tag: New Tag\n- prometheus-demo-dashboard: Prometheus - Demo Dashboard\n- prometheus-alerting: Prometheus alerting\n- prometheus-console: Prometheus Console?\n- prometheus-repeat: Prometheus repeat\n- prometheus-templating: Prometheus templating\n- repeat-issue: Repeat issue\n- repeat-rows: Repeat rows\n- repeated-rows: Repeated rows\n- scrolltest: ScrollTest\n- sending-metrics: Sending metrics\n- singlestat-showcase: Singlestat showcase\n- span6: Span6\n- stats: Stats\n- stats-installs: Stats Installs\n- stats-version-trends: Stats Version Trends\n- table-panel-showcase: Table Panel Showcase\n- table-to-the-right: Table to the right\n- templating: Templating\n- templating-showcase: Templating showcase\n- templating-value-groups: Templating value groups\n- templating-repeated-panels: Templating, repeated panels\n- testdata-alerts: TestData - Alerts\n- testdata-graph-panel-last-1h: TestData - Graph Panel Last 1h\n- testing: Testing\n- testing-nesting-more: Testing nesting more\n- text-panel: Text panel\n- the-color-of-monitoring-1: The Color of Monitoring - 1\n- the-color-of-monitoring-2: The Color of Monitoring - 2\n- the-color-of-monitoring-3: The Color of Monitoring - 3\n- the-four-golden-signals: The Four Golden Signals\n- theshold-test: Theshold test\n- threshold-example: Threshold example\n- time-range-override: Time range override\n- today: Today\n- two-y-axis: Two Y-Axis\n- ultimate-graphite-query-guide: Ultimate Graphite Query Guide\n- emoji: 🍾 Emoji 🍾\n"]
      ]

  context 'ask hubot to list dashboards filterd by tag', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/search?type=dash-db&tag=demo')
        .replyWithFile(200, __dirname + '/fixtures/search-tag-v5.json')
      room.user.say 'alice', 'hubot graf list demo'
      setTimeout done, 100

    it 'hubot should respond with a list of dashboards with tag', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf list demo' ]
        [ 'hubot', "Dashboards tagged `demo`:\n- alerting: Alerting\n- annotations: Annotations\n- big-dashboard: Big Dashboard\n- graph-styles: Graph styles\n- templating: Templating\n"]
      ]

  context 'ask hubot to search dashboards', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/search?type=dash-db&query=elasticsearch')
        .replyWithFile(200, __dirname + '/fixtures/search-query-v5.json')
      room.user.say 'alice', 'hubot graf search elasticsearch'
      setTimeout done, 100

    it 'hubot should respond with a matching dashboard', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf search elasticsearch' ]
        [ 'hubot', "Dashboards matching `elasticsearch`:\n- elasticsearch-derivative: Elasticsearch Derivative\n- elasticsearch-metrics: Elasticsearch Metrics\n- elasticsearch-metrics-filter: Elasticsearch Metrics Filter\n- elasticsearch-query-filter: Elasticsearch query filter\n- elasticsearch-templated: Elasticsearch Templated\n- elasticsearch-templated-fields: Elasticsearch Templated Fields\n"]
      ]

  context 'ask hubot to return a specific panel by API ID', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v5.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:panel-8'
      setTimeout done, 100

    it 'hubot should respond with a matching dashboard', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:panel-8' ]
        [ 'hubot', "What's New: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=1000&height=500&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot to return a specific panel by visual ID', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v5.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3'
      setTimeout done, 100

    it 'hubot should respond with a matching dashboard', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3' ]
        [ 'hubot', "What's New: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=1000&height=500&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot to return different default image sizes', ->
    beforeEach (done) ->
      process.env.HUBOT_GRAFANA_DEFAULT_WIDTH = 1024
      process.env.HUBOT_GRAFANA_DEFAULT_HEIGHT = 768
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v5.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3'
      setTimeout done, 100
    afterEach ->
      delete process.env.HUBOT_GRAFANA_DEFAULT_WIDTH
      delete process.env.HUBOT_GRAFANA_DEFAULT_HEIGHT

    it 'hubot should respond with the custom image size set in environment', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3' ]
        [ 'hubot', "What's New: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=1024&height=768&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot to return a specific panel with a custom size', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v5.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3 width=2500 height=700'
      setTimeout done, 100

    it 'hubot should respond with a resized image specified in request', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3 width=2500 height=700' ]
        [ 'hubot', "What's New: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=2500&height=700&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]
  context 'ask hubot to return a specific panel with a custom size in any order', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/grafana-play-home')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-grafana-play-v5.json')
      room.user.say 'alice', 'hubot graf db grafana-play-home:3 height=700 width=2500'
      setTimeout done, 100

    it 'hubot should respond with a resized image specified in request', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db grafana-play-home:3 height=700 width=2500' ]
        [ 'hubot', "What's New: http://play.grafana.org/render/dashboard-solo/db/grafana-play-home/?panelId=8&width=2500&height=700&from=now-6h&to=now - http://play.grafana.org/dashboard/db/grafana-play-home/?panelId=8&fullscreen&from=now-6h&to=now"]
      ]

  context 'ask hubot for templated dashboard', ->
    beforeEach (done) ->
      nock('http://play.grafana.org')
        .get('/api/dashboards/db/templating')
        .replyWithFile(200, __dirname + '/fixtures/dashboard-templating-v5.json')
      room.user.say 'alice', 'hubot graf db templating:requests server=backend_01 now-6h'
      setTimeout done, 100

    it 'hubot should respond with a templated graph', ->
      expect(room.messages).to.eql [
        [ 'alice', 'hubot graf db templating:requests server=backend_01 now-6h' ]
        [ 'hubot', 'Requests / s: http://play.grafana.org/render/dashboard-solo/db/templating/?panelId=1&width=1000&height=500&from=now-6h&to=now&var-server=backend_01 - http://play.grafana.org/dashboard/db/templating/?panelId=1&fullscreen&from=now-6h&to=now&var-server=backend_01']
      ]
