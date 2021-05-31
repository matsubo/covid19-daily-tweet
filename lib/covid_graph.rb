# frozen_string_literal: true

# Make a historical graph
#
# ```
#
# require 'bundler/setup'
# Bundler.require
#
# require 'yaml'
# account = YAML.load_file('settings.yaml')['accounts']['tokyo']
#
# file = CovidGraph.new(File.open('downloads/tokyo.csv'), account).create
# FileUtils.chmod(0644, file)
# FileUtils.copy(file, 'test.png')
# ```
#
class CovidGraph
  def initialize(file, account, base_date = nil)
    @file = file
    @account = account
    @base_date = base_date || Time.now
  end

  def create
    dataset = create_dataset
    g = Gruff::StackedBar.new
    g.colors = colors(get_categories(dataset))
    g.font = './vendor/HackGen/HackGen-Regular.ttf'
    g.legend_font_size = 14
    g.title = format('%{area}のCOVID-19新規陽性者数', area: @account['prefecture_ja'])

    g.labels = eliminate_label(dates)
    create_count_dataset(dataset).each do |record|
      g.data record[0], record[1]
    end

    # file extension is required by Gruff.
    tempfile = Tempfile.new(['gruff', '.png'])

    g.write(tempfile.path)

    # for debug
    # FileUtils.copy(tempfile, 'gruff-example.png')

    tempfile
  end

  private

  def dates
    result = {}
    index = 0
    date = Date.new(2020, 1, 15)
    while date <= @base_date.to_date
      result[index] = date
      date += 1
      index += 1
    end
    result
  end

  # Omitt the label title
  def eliminate_label(labels)
    index = 0
    labels.each do |key, date|
      labels[key] = if @base_date.to_date == date
                      date.strftime('%-m/%-d')
                    elsif !(index == 0 || index == (labels.count - 1) || index % 25 == 0) || @base_date.to_date - 65 < date
                      ''
                    else
                      date.strftime('%-m/%-d')
                    end
      index += 1
    end
    labels
  end

  # Parse the csv file and return structed Hash data
  # @return Hash
  def create_dataset
    require 'date'

    actualy_col_index = @account['column'].to_i - 1
    age_column_index = @account['age_column'].to_i - 1

    dataset = {}

    CSV.foreach(@file, headers: true, encoding: @account['encoding']) do |row|
      next if row.length < 0
      next if row[actualy_col_index].nil? # next if empty column

      date_string = row[actualy_col_index]
      date_string.gsub!(/[年月]/, '/') # 日本語をparseできない
      date_string.gsub!(/日$/, '')
      date = Date.parse(date_string) rescue nil

      age = (row[age_column_index] || '不明').strip.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z').gsub(/[\r\n]/, '')
      age.gsub!('ー', '不明') # for okayama
      age.gsub!('\'-', '不明') # for tokyo
      age.gsub!('-', '不明')
      age.gsub!('ー', '不明')
      age.gsub!('−', '不明')

      dataset[date] ||= {}
      dataset[date][age] = (dataset[date][age] || 0) + 1
    end

    dataset
  end

  # return sorted category
  # @return Array
  def get_categories(dataset)
    categories = []
    dataset.each do |_date, hash|
      categories = categories.concat(hash.keys).uniq
    end

    # left is more bottom
    sort_model = [
      '乳児',
      '1歳未満',
      '未就学児',
      '10代未満',
      '10未満',
      '10歳未満',
      '小学生',
      '10代',
      '生徒',
      '学生',
      '未成年',
      '20代',
      '30代',
      '40代',
      '50代',
      '60代',
      '70代',
      '80代',
      '90代',
      '90歳以上',
      '100代',
      '100歳以上',
      '高齢者',
      '不明',
      '非公表',
      '-',
      '−'
    ]

    categories.sort { |a, b| (sort_model.index(a) || sort_model.count) <=> (sort_model.index(b) || sort_model.count) }
  end

  # create hash data for Gruff from the passed data
  # @return Hash
  def create_count_dataset(dataset)
    new_data = []
    get_categories(dataset).each do |category|
      metric_data = []
      dates.each do |data|
        date = data[1]
        metric_data << ((dataset[date][category] || 0) rescue 0)
      end
      new_data << [category, metric_data]
    end
    new_data
  end

  def colors(categories)
    require 'json'
    JSON.parse(File.read('colors.json')).values[0, categories.size]
  end
end
