# frozen_string_literal: true

require 'faraday'
require 'base64'
require 'json'
require 'date'

class Wordpress

  def initialize(key)
    @key = key.to_sym
  end

  def post(message, file)

    wordpress_yaml = YAML.load_file('wordpress.yaml')

    authorization = 'Basic ' + Base64.encode64('%s:%s'%[wordpress_yaml['login']['user'], wordpress_yaml['login']['password']])

    # post image
    wp_api_url = wordpress_yaml['login']['endpoint']

    setting = {
      tokyo: {
        prefecture_jp: '東京都',
        category: '2',
      },
      kanagawa: {
        prefecture_jp: '神奈川都',
        category: '2',
      }
    }

    raise 'no setting' unless setting[@key]

    prefecture = @key.to_s
    prefecture_jp = setting[@key][:prefecture_jp]
    category = setting[@key][:category]


    date_jp = Date.today.strftime('%Y年%m月%d日')
    date_yyyymmdd = Date.today.strftime('%Y-%m-%d')

    connection = Faraday.new(wp_api_url, { ssl: { verify: false } }) do |builder|
      builder.request :multipart
      builder.request :url_encoded
      builder.adapter Faraday.default_adapter
    end
    connection.headers['Authorization'] = authorization
    params = { file: Faraday::UploadIO.new(file, 'image/png') }

    response = JSON.parse(connection.post('media', params).body)

    p response

    # post article
    header = {
      'Content-Type' => 'application/json',
      'Authorization' => authorization
    }

    html = format('
<!-- wp:paragraph -->
<p>%s</p>
<!-- /wp:paragraph -->

<!-- wp:image {"id":%d,"sizeSlug":"large"} -->
<figure class="wp-block-image size-large"><img src="%s" alt="" class="wp-image-%s"/></figure>
<!-- /wp:image -->
                  ', message, response['id'], response['media_details']['sizes']['full']['source_url'], response['id'])

    post_data = {
      title: '%s %sの新型コロナウィルス新規陽性者数'%[date_jp, prefecture_jp],
      content: html,
      status: 'draft', # publish
      categories: category,
      slug: date_yyyymmdd + '_' +prefecture,
      featured_media: response['id'],
      tags: '1'
    }.to_json
    response = Faraday.post(wp_api_url + '/posts', post_data, header)
    p JSON.parse(response.body)



  end
end
