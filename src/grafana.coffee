# Description:
#   Query Grafana dashboards
#
#   Examples:
#   - `hubot graf db graphite-carbon-metrics` - Get all panels in the dashboard
#   - `hubot graf db graphite-carbon-metrics:3` - Get only the third panel, from left to right, of a particular dashboard
#   - `hubot graf db graphite-carbon-metrics:3 width=1000` - Get only the third panel, from left to right, of a particular dashboard. Set the image width to 1000px
#   - `hubot graf db graphite-carbon-metrics:3 height=2000` - Get only the third panel, from left to right, of a particular dashboard. Set the image height to 2000px
#   - `hubot graf db graphite-carbon-metrics:panel-8` - Get only the panel of a particular dashboard with the ID of 8
#   - `hubot graf db graphite-carbon-metrics:cpu` - Get only the panels containing "cpu" (case insensitive) in the title
#   - `hubot graf db graphite-carbon-metrics now-12hr` - Get a dashboard with a window of 12 hours ago to now
#   - `hubot graf db graphite-carbon-metrics now-24hr now-12hr` - Get a dashboard with a window of 24 hours ago to 12 hours ago
#   - `hubot graf db graphite-carbon-metrics:3 now-8d now-1d` - Get only the third panel of a particular dashboard with a window of 8 days ago to yesterday
#
# Configuration:
#   HUBOT_GRAFANA_HOST - Host for your Grafana 2.0 install, e.g. 'http://play.grafana.org'
#   HUBOT_GRAFANA_API_KEY - API key for a particular user (leave unset if unauthenticated)
#   HUBOT_GRAFANA_QUERY_TIME_RANGE - Optional; Default time range for queries (defaults to 6h)
#   HUBOT_GRAFANA_DEFAULT_WIDTH - Optional; Default width for rendered images (defaults to 1000)
#   HUBOT_GRAFANA_DEFAULT_HEIGHT - Optional; Default height for rendered images (defaults to 500)
#   HUBOT_GRAFANA_S3_ENDPOINT - Optional; Endpoint of the S3 API (useful for S3 compatible API, defaults to s3.amazonaws.com)
#   HUBOT_GRAFANA_S3_BUCKET - Optional; Name of the S3 bucket to copy the graph into
#   HUBOT_GRAFANA_S3_ACCESS_KEY_ID - Optional; Access key ID for S3
#   HUBOT_GRAFANA_S3_SECRET_ACCESS_KEY - Optional; Secret access key for S3
#   HUBOT_GRAFANA_S3_PREFIX - Optional; Bucket prefix (useful for shared buckets)
#   HUBOT_GRAFANA_S3_REGION - Optional; Bucket region (defaults to us-standard)
#
# Dependencies:
#   "knox": "^0.9.2"
#   "request": "~2"
#
# Notes:
#   If you want to use the Slack adapter's "attachment" formatting:
#     hubot: v2.7.2+
#     hubot-slack: 4.0+
#
# Commands:
#   hubot graf db <dashboard slug>[:<panel id>][ <template variables>][ <from clause>][ <to clause>] - Show grafana dashboard graphs
#   hubot graf list <tag> - Lists all dashboards available (optional: <tag>)
#   hubot graf search <keyword> - Search available dashboards by <keyword>
#

crypto  = require 'crypto'
knox    = require 'knox'
request = require 'request'

module.exports = (robot) ->
  # Various configuration options stored in environment variables
  grafana_host = process.env.HUBOT_GRAFANA_HOST
  grafana_api_key = process.env.HUBOT_GRAFANA_API_KEY
  grafana_query_time_range = process.env.HUBOT_GRAFANA_QUERY_TIME_RANGE or '6h'
  s3_endpoint = process.env.HUBOT_GRAFANA_S3_ENDPOINT or 's3.amazonaws.com'
  s3_bucket = process.env.HUBOT_GRAFANA_S3_BUCKET
  s3_access_key = process.env.HUBOT_GRAFANA_S3_ACCESS_KEY_ID
  s3_secret_key = process.env.HUBOT_GRAFANA_S3_SECRET_ACCESS_KEY
  s3_prefix = process.env.HUBOT_GRAFANA_S3_PREFIX
  s3_style = process.env.HUBOT_GRAFANA_S3_STYLE if process.env.HUBOT_GRAFANA_S3_STYLE
  s3_region = process.env.HUBOT_GRAFANA_S3_REGION or 'us-standard'
  s3_port = process.env.HUBOT_GRAFANA_S3_PORT if process.env.HUBOT_GRAFANA_S3_PORT
  slack_token = process.env.HUBOT_SLACK_TOKEN
  rocketchat_url = process.env.ROCKETCHAT_URL
  rocketchat_user = process.env.ROCKETCHAT_USER
  rocketchat_password = process.env.ROCKETCHAT_PASSWORD

  if rocketchat_url && ! rocketchat_url.startsWith 'http'
    rocketchat_url = 'http://' + rocketchat_url

  site = () ->
    # prioritize S3 no matter if adpater is slack or rocketchat
    if (s3_bucket && s3_access_key && s3_secret_key)
      's3'
    else if (robot.adapterName == 'slack')
      'slack'
    else if (robot.adapterName == 'rocketchat')
      'rocketchat'
    else
      ''
  isUploadSupported = site() != ''

  # Get a specific dashboard with options
  robot.respond /(?:grafana|graph|graf) (?:dash|dashboard|db) ([A-Za-z0-9\-\:_]+)(.*)?/i, (msg) ->
    slug = msg.match[1].trim()
    remainder = msg.match[2]
    timespan = {
      from: "now-#{grafana_query_time_range}"
      to: 'now'
    }
    variables = ''
    template_params = []
    visualPanelId = false
    apiPanelId = false
    pname = false
    imagesize =
      width: process.env.HUBOT_GRAFANA_DEFAULT_WIDTH or 1000
      height: process.env.HUBOT_GRAFANA_DEFAULT_HEIGHT or 500

    # Parse out a specific panel
    if /\:/.test slug
      parts = slug.split(':')
      slug = parts[0]
      visualPanelId = parseInt parts[1], 10
      if isNaN visualPanelId
        visualPanelId = false
        pname = parts[1].toLowerCase()
      if /panel-[0-9]+/.test pname
        parts = pname.split('panel-')
        apiPanelId = parseInt parts[1], 10
        pname = false

    # Check if we have any extra fields
    if remainder
      # The order we apply non-variables in
      timeFields = ['from', 'to']

      for part in remainder.trim().split ' '
        # Check if it's a variable or part of the timespan
        if part.indexOf('=') >= 0
          #put imagesize stuff into its own dict
          if part.split('=')[0] of imagesize
            imagesize[part.split('=')[0]] = part.split('=')[1]
            continue

          variables = "#{variables}&var-#{part}"
          template_params.push { "name": part.split('=')[0], "value": part.split('=')[1] }

        # Only add to the timespan if we haven't already filled out from and to
        else if timeFields.length > 0
          timespan[timeFields.shift()] = part.trim()

    robot.logger.debug msg.match
    robot.logger.debug slug
    robot.logger.debug timespan
    robot.logger.debug variables
    robot.logger.debug template_params
    robot.logger.debug visualPanelId
    robot.logger.debug apiPanelId
    robot.logger.debug pname

    # Call the API to get information about this dashboard
    callGrafana "dashboards/db/#{slug}", (dashboard) ->
      robot.logger.debug dashboard

      # Check dashboard information
      if !dashboard
        return sendError 'An error ocurred. Check your logs for more details.', msg
      if dashboard.message
        return sendError dashboard.message, msg

      # Defaults
      apiEndpoint = 'dashboard-solo'
      data = dashboard.dashboard

      # Handle refactor done for version 5.0.0+
      if dashboard.dashboard.panels
        # Concept of "rows" was replaced by coordinate system
        data.rows = [dashboard.dashboard]

      # Handle empty dashboard
      if !data.rows?
        return sendError 'Dashboard empty.', msg

      # Support for templated dashboards
      robot.logger.debug data.templating.list
      if data.templating.list
        template_map = []
        for template in data.templating.list
          robot.logger.debug template
          continue unless template.current
          for _param in template_params
            if template.name == _param.name
              template_map['$' + template.name] = _param.value
            else
              template_map['$' + template.name] = template.current.text

      # Return dashboard rows
      panelNumber = 0
      for row in data.rows
        for panel in row.panels
          robot.logger.debug panel

          panelNumber += 1
          # Skip if visual panel ID was specified and didn't match
          if visualPanelId && visualPanelId != panelNumber
            continue

          # Skip if API panel ID was specified and didn't match
          if apiPanelId && apiPanelId != panel.id
            continue

          # Skip if panel name was specified any didn't match
          if pname && panel.title.toLowerCase().indexOf(pname) is -1
            continue

          # Build links for message sending
          title = formatTitleWithTemplate(panel.title, template_map)
          imageUrl = "#{grafana_host}/render/#{apiEndpoint}/db/#{slug}/?panelId=#{panel.id}&width=#{imagesize.width}&height=#{imagesize.height}&from=#{timespan.from}&to=#{timespan.to}#{variables}"
          link = "#{grafana_host}/dashboard/db/#{slug}/?panelId=#{panel.id}&fullscreen&from=#{timespan.from}&to=#{timespan.to}#{variables}"

          sendDashboardChart msg, title, imageUrl, link

  # Process the bot response
  sendDashboardChart = (msg, title, imageUrl, link) ->
    if (isUploadSupported)
      uploadChart msg, title, imageUrl, link, site
    else
      sendRobotResponse msg, title, imageUrl, link

  # Get a list of available dashboards
  robot.respond /(?:grafana|graph|graf) list\s?(.+)?/i, (msg) ->
    if msg.match[1]
      tag = msg.match[1].trim()
      callGrafana "search?type=dash-db&tag=#{tag}", (dashboards) ->
        robot.logger.debug dashboards
        response = "Dashboards tagged `#{tag}`:\n"
        sendDashboardList dashboards, response, msg
    else
      callGrafana 'search?type=dash-db', (dashboards) ->
        robot.logger.debug dashboards
        response = "Available dashboards:\n"
        sendDashboardList dashboards, response, msg

  # Search dashboards
  robot.respond /(?:grafana|graph|graf) search (.+)/i, (msg) ->
    query = msg.match[1].trim()
    robot.logger.debug query
    callGrafana "search?type=dash-db&query=#{query}", (dashboards) ->
      robot.logger.debug dashboards
      response = "Dashboards matching `#{query}`:\n"
      sendDashboardList dashboards, response, msg

  # Send Dashboard list
  sendDashboardList = (dashboards, response, msg) ->
    # Handle refactor done for version 2.0.2+
    if dashboards.dashboards
      list = dashboards.dashboards
    else
      list = dashboards

    robot.logger.debug list
    unless list.length > 0
      return

    for dashboard in list
      # Handle refactor done for version 2.0.2+
      if dashboard.uri
        slug = dashboard.uri.replace /^db\//, ''
      else
        slug = dashboard.slug
      response = response + "- #{slug}: #{dashboard.title}\n"

    # Remove trailing newline
    response.trim()

    msg.send response

  # Handle generic errors
  sendError = (message, msg) ->
    robot.logger.error message
    msg.send message

  # Format the title with template vars
  formatTitleWithTemplate = (title, template_map) ->
    title.replace /\$\w+/g, (match) ->
      if template_map[match]
        return template_map[match]
      else
        return match

  # Send robot response
  sendRobotResponse = (msg, title, image, link) ->
    switch robot.adapterName
      # Slack
      when 'slack'
        msg.send {
          attachments: [
            {
              fallback: "#{title}: #{image} - #{link}",
              title: title,
              title_link: link,
              image_url: image
            }
          ],
          unfurl_links: false
        }
      # Hipchat
      when 'hipchat'
        msg.send "#{title}: #{link} - #{image}"
      # BearyChat
      when 'bearychat'
        robot.emit 'bearychat.attachment', {
          message:
            room: msg.envelope.room
          text: "[#{title}](#{link})"
          attachments: [
            {
              fallback: "#{title}: #{image} - #{link}",
              images: [
                url: image
              ]
            }
          ],
        }
      # Everything else
      else
        msg.send "#{title}: #{image} - #{link}"

  # Call off to Grafana
  callGrafana = (url, callback) ->
    if grafana_api_key
      authHeader = {
        'Accept': 'application/json',
        'Authorization': "Bearer #{grafana_api_key}"
      }
    else
      authHeader = {
        'Accept': 'application/json'
      }
    robot.http("#{grafana_host}/api/#{url}").headers(authHeader).get() (err, res, body) ->
      if (err)
        robot.logger.error err
        return callback(false)
      data = JSON.parse(body)
      return callback(data)

  # Pick a random filename
  uploadPath = () ->
    prefix = s3_prefix || 'grafana'
    "#{prefix}/#{crypto.randomBytes(20).toString('hex')}.png"

  uploadTo =
    's3': (msg, title, grafanaDashboardRequest, link) ->
      grafanaDashboardRequest (err, res, body) ->
        client = knox.createClient {
          key      : s3_access_key
          secret   : s3_secret_key,
          bucket   : s3_bucket,
          region   : s3_region,
          endpoint : s3_endpoint,
          port     : s3_port,
          style    : s3_style,
        }

        headers = {
          'Content-Length' : body.length,
          'Content-Type'   : res.headers['content-type'],
          'x-amz-acl'      : 'public-read',
          'encoding'       : null
        }

        filename = uploadPath()

        if s3_port
          image_url = client.http(filename)
        else
          image_url = client.https(filename)

        req = client.put(filename, headers)

        req.on 'response', (res) ->

          if (200 == res.statusCode)
            sendRobotResponse msg, title, image_url, link
          else
            robot.logger.debug res
            robot.logger.error "Upload Error Code: #{res.statusCode}"
            msg.send "#{title} - [Upload Error] - #{link}"

        req.end body

    'slack': (msg, title, grafanaDashboardRequest, link) ->
      testAuthData =
        url: 'https://slack.com/api/auth.test'
        formData:
          token: slack_token

      # We test auth against slack to obtain the team URL
      request.post testAuthData, (err, httpResponse, slackResBody) ->
          if err
            robot.logger.error err
            msg.send "#{title} - [Slak auth.test Error - invalid token/can't fetch team url] - #{link}"
          else
            slack_url = JSON.parse(slackResBody)["url"]

            # fill in the POST request. This must be www-form/multipart
            uploadData =
              url: slack_url + '/api/files.upload'
              formData:
                channels: msg.envelope.room
                token: slack_token
                # grafanaDashboardRequest() is the method that downloads the .png
                file: grafanaDashboardRequest()

            # Try to upload the image to slack else pass the link over
            request.post uploadData, (err, httpResponse, body) ->
              res = JSON.parse(body)

              # Error logging, we must also check the body response.
              # It will be something like: { "ok": <boolean>, "error": <error message> }
              if err
                robot.logger.error err
                msg.send "#{title} - [Upload Error] - #{link}"
              else if !res["ok"]
                robot.logger.error "Slack service error while posting data:" +res["error"]
                msg.send "#{title} - [Form Error: can't upload file] - #{link}"

    'rocketchat': (msg, title, grafanaDashboardRequest, link) ->
      authData =
        url: rocketchat_url + '/api/v1/login'
        form:
          username: rocketchat_user
          password: rocketchat_password

      # We auth against rocketchat to obtain the auth token
      request.post authData, (err, httpResponse, rocketchatResBody) ->
          if err
            robot.logger.error err
            msg.send "#{title} - [Rocketchat auth Error - invalid url, user or password/can't access rocketchat api] - #{link}"
          else
            status = JSON.parse(rocketchatResBody)["status"]
            if status != "success"
              errMsg = JSON.parse(rocketchatResBody)["message"]
              robot.logger.error errMsg
              msg.send "#{title} - [Rocketchat auth Error - #{errMsg}] - #{link}"

            auth = JSON.parse(rocketchatResBody)["data"]

            # fill in the POST request. This must be www-form/multipart
            uploadData =
              url: rocketchat_url + '/api/v1/rooms.upload/' + msg.envelope.user.roomID
              headers:
                'X-Auth-Token': auth.authToken
                'X-User-Id': auth.userId
              formData:
                msg: "#{title}: #{link}"
                # grafanaDashboardRequest() is the method that downloads the .png
                file:
                  value: grafanaDashboardRequest()
                  options:
                    filename: "#{title} #{Date()}.png",
                    contentType: 'image/png'

            # Try to upload the image to rocketchat else pass the link over
            request.post uploadData, (err, httpResponse, body) ->
              res = JSON.parse(body)

              # Error logging, we must also check the body response.
              # It will be something like: { "success": <boolean>, "error": <error message> }
              if err
                robot.logger.error err
                msg.send "#{title} - [Upload Error] - #{link}"
              else if !res["success"]
                errMsg = res["error"]
                robot.logger.error "rocketchat service error while posting data:" +errMsg
                msg.send "#{title} - [Form Error: can't upload file : #{errMsg}] - #{link}"

  # Fetch an image from provided URL, upload it to S3, returning the resulting URL
  uploadChart = (msg, title, url, link, site) ->
    if grafana_api_key
      requestHeaders =
        encoding: null,
        auth:
          bearer: grafana_api_key
    else
      requestHeaders =
        encoding: null

    # Pass this function along to the "registered" services that uploads the image.
    # The function will donwload the .png image(s) dashboard. You must pass this
    # function and use it inside your service upload implementation.
    grafanaDashboardRequest = (callback) ->
      request url, requestHeaders, (err, res, body) ->
        robot.logger.debug "Uploading file: #{body.length} bytes, content-type[#{res.headers['content-type']}]"
        if callback
          callback(err, res, body)

    uploadTo[site()](msg, title, grafanaDashboardRequest, link)

