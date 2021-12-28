# frozen_string_literal: true

require 'faraday'
require 'base64'
require 'json'
require 'date'
require 'logger'

#
# Upload a graph image and use it in the post
#
class Wordpress
  def initialize(key, base_date = nil)
    @key = key
    @logger = Logger.new(($stdout unless ENV['TEST']))
    @base_date = base_date || Time.now
  end

  def post(message, file)
    wordpress_yaml = YAML.load_file('wordpress.yaml')

    authorization = 'Basic ' + Base64.encode64(format('%s:%s', wordpress_yaml['login']['user'], wordpress_yaml['login']['password']))

    # post image
    wp_api_url = wordpress_yaml['login']['endpoint']

    prefecture = @key

    prefecture_jp = wordpress_yaml['parameter'][@key]['prefecture_jp']
    category = wordpress_yaml['parameter'][@key]['category']

    date_jp = @base_date.to_date.strftime('%Y年%-m月%-d日')

    connection = Faraday.new(wp_api_url, { ssl: { verify: false } }) do |builder|
      builder.request :multipart
      builder.request :url_encoded
      builder.adapter Faraday.default_adapter
    end
    connection.headers['Authorization'] = authorization

    alt = format('%s %s 新型コロナウイルス新規陽性者数 グラフ', date_jp, prefecture_jp)
    params = {
      alt_text: alt,
      title: alt,
      description: alt,
      file: Faraday::UploadIO.new(file, 'image/png')
    }

    response = JSON.parse(connection.post('media', params).body)

    # post article
    header = {
      'Content-Type' => 'application/json',
      'Authorization' => authorization
    }

    html = format('
<!-- wp:paragraph -->
<p>%s</p>
<!-- /wp:paragraph -->

<!-- wp:image {"id":%d,"sizeSlug":"large","linkDestination":"media"} -->
<figure class="wp-block-image size-large"><a href="%s"><img src="%s" alt="%s" class="wp-image-%s"/></a></figure>
<!-- /wp:image -->

                  ',
                  message,
                  response['id'],
                  response['media_details']['sizes']['full']['source_url'],
                  response['media_details']['sizes']['full']['source_url'],
                  alt,
                  response['id'])

    @logger.debug(html)

    post_data = {
      title: format('%s %sの新型コロナウイルス新規陽性者数', date_jp, prefecture_jp),
      content: html,
      status: 'publish', # publish
      categories: category,
      slug: prefecture,
      featured_media: response['id'],
      date: @base_date.strftime('%Y-%m-%dT%H:%M:%S'),
      tags: '1'
    }.to_json
    response = Faraday.post(wp_api_url + '/posts', post_data, header)

    raise 'post failed: ' + JSON.parse(response.body).to_s unless response.status == 201

    response_hash = JSON.parse(response.body)

    @logger.info(response_hash['link'])

    response_hash
  end
end
