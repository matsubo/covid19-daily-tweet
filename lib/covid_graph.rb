# frozen_string_literal: true

# Make a historical graph
#
# ```
# require 'bundler/setup'
# Bundler.require
#
#
#
# require 'yaml'
# account = YAML.load_file('settings.yaml')['accounts'][2]
#
# CovidGraph.new(File.open('downloads/tokyo.csv'), account).create
# ```
#
class CovidGraph
  def initialize(file, account)
    @file = file
    @account = account
  end

  def create
    dataset = create_dataset

    g = Gruff::StackedBar.new
    g.font = './vendor/HackGen/HackGen-Regular.ttf'
    g.title = format('%{area}のCOVID-19新規陽性者数', area: @account['prefecture_ja'])

    pp get_label_for_label(get_label)

    g.labels = get_label_for_label(get_label)
    create_count_dataset(dataset).each do |record|
      g.data record[0], record[1]
    end

    # pp get_label_for_label(get_label)
    pp create_count_dataset(dataset)[0][1].count

    tempfile = Tempfile.new(['gruff', '.png'])

    g.write(tempfile.path)

    FileUtils.copy(tempfile, 'gruff-example.png')

    tempfile
  end

  def get_label
    result = {}
    index = 0
    date = Date.new(2020, 1, 15)
    while date <= Date.today
      result[index] = date
      date += 1
      index += 1
    end
    result
  end

  def get_label_for_label(labels)
    index = 0
    labels.each do |key, date|
      labels[key] = if !(index == 0 || index == (labels.count - 1) || index % 20 == 0) || Date.today - 20 < date
                      ''
                    else
                      date.strftime('%-m/%-d')
                    end
      index += 1
    end
    labels
  end

  def create_dataset
    require 'date'

    actualy_col_index = @account['column'].to_i - 1
    age_column_index = @account['age_column'].to_i - 1

    dataset = {}

    CSV.foreach(@file, headers: true, encoding: @account['encoding']) do |row|
      next if row.length < 0

      date = Date.parse(row[actualy_col_index])
      age = (row[age_column_index] || '不明').strip

      dataset[date] ||= {}
      dataset[date][age] = (dataset[date][age] || 0) + 1
    end

    dataset
  end

  def get_categories(dataset)
    categories = []
    dataset.each do |_date, hash|
      categories = categories.concat(hash.keys).uniq
    end
    categories.sort { |a, b| a.to_i <=> b.to_i }
  end

  def create_count_dataset(dataset)
    new_data = []
    get_categories(dataset).each do |category|
      metric_data = []
      get_label.each do |data|
        date = data[1]
        metric_data << ((dataset[date][category] || 0) rescue 0)
      end
      new_data << [category, metric_data]
    end
    new_data
  end
end

#require 'bundler/setup'
#Bundler.require
#
#require 'yaml'
#
# account = YAML.load_file('settings.yaml')['accounts'][4]
# CovidGraph.new(File.open('downloads/mie20200718.csv'), account).create

# account = YAML.load_file('settings.yaml')['accounts'][2]
# CovidGraph.new(File.open('downloads/tokyo.csv'), account).create

#account = YAML.load_file('settings.yaml')['accounts'][3]
#CovidGraph.new(File.open('downloads/kanagawa.csv'), account).create
