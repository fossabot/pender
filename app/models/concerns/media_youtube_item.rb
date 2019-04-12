module MediaYoutubeItem
  extend ActiveSupport::Concern

  included do
    Media.declare('youtube_item', [/^https?:\/\/(www\.)?youtube\.com\/watch\?v=([^&]+)/])
  end

  def youtube_item_direct_attributes
    %w(
      description
      title
      published_at
      thumbnails
      embed_html
      channel_title
      channel_id
    )
  end

  def data_from_youtube_item
    self.data[:raw][:api] = {}
    self.data[:html] = ''
    handle_exceptions(self, Yt::Errors::NoItems) do
      video = Yt::Video.new url: self.url
      video_data = video.snippet.data
      self.youtube_item_direct_attributes.each do |attr|
        self.data[:raw][:api][attr] =
          begin
            video_data.dig(attr.camelize(:lower)) || video.send(attr)
          rescue Exception => e
            ''
          end
      end
      data = self.data

      self.data.merge!({
        username: get_info_from_data('api', data, 'channel_title'),
        description: get_info_from_data('api', data, 'description'),
        title: get_info_from_data('api', data, 'title'),
        picture: self.get_youtube_thumbnail,
        html: get_info_from_data('api', data, 'embed_html'),
        author_name: get_info_from_data('api', data, 'channel_title'),
        author_picture: self.get_youtube_item_author_picture,
        author_url: 'https://www.youtube.com/channel/' + get_info_from_data('api', data, 'channel_id'),
        published_at: get_info_from_data('api', data, 'published_at')
      })
    end
  end

  def get_youtube_thumbnail
    thumbnails = self.get_info_from_data('api', data, 'thumbnails')
    return '' unless thumbnails.is_a?(Hash)
    ['maxres', 'standard', 'high', 'medium', 'default'].each do |size|
      return thumbnails.dig(size, 'url') unless thumbnails.dig(size).nil?
    end
  end

  def get_youtube_item_author_picture
    channel = Yt::Channel.new id: self.data[:raw][:api]['channel_id']
    channel.thumbnail_url.to_s
  end

  def youtube_oembed_url
    "https://www.youtube.com/oembed?format=json&url=#{self.url}"
  end

end
