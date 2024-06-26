# covid19-daily-tweet

[![Ruby](https://github.com/matsubo/covid19-daily-tweet/workflows/Ruby/badge.svg)](https://github.com/matsubo/covid19-daily-tweet/actions)
[![Discord Shield](https://discordapp.com/api/guilds/725542623594545233/widget.png?style=shield)](https://discord.gg/sSfEha)

![image](https://user-images.githubusercontent.com/98103/208041488-bb6d114c-6678-449e-bad0-78b597910887.png)

## For Japanese 

- [新型コロナウイルス感染症対策に関するオープンデータ項目定義書](https://docs.google.com/spreadsheets/d/1fJtqxqh_4OuUwq2LQ_WRx23fwcEB4hNL/edit#gid=1874865803)フォーマットで提供されている（またはプログラムにとって可読性の高いファイルが提供されている）都道府県のデータを10分に1回クロールして新規感染者がでた場合はTweetし、[Blog](https://covid19.teraren.com/)にも投稿します。
- 運用しているTwitter Botは[神奈川県](https://twitter.com/covid19kanagawa)のみになります。その他の都道府県のアカウントはBanされてしまいました。
- pull-requestやissueの内容の解決はウェルカムです。

## For English

- This program tweets once a day to report the number of positiver person of COVID-19. Some government of prefectures provide with [COVID-19 report open deta definitions](https://docs.google.com/spreadsheets/d/1fJtqxqh_4OuUwq2LQ_WRx23fwcEB4hNL/edit#gid=1874865803) format this program check the file update and tweet if there are new records.
- pull-request and resolving issues are welcomed.
- [List of operating twitter bot](https://covid19.teraren.com/).

## Setup

```
% cp twitter.yaml.template twitter.yaml
% vi twitter.yaml
% cp wordpress.yaml.template wordpress.yaml
% vi wordpress.yaml
% docker-compose run --rm app bundle
```

## Run

Manually
```
% docker-compose run app bundle exec ruby main.rb
```

Daemon in background
```
% docker-compose up -d 
```

## Cron

```
15,30,45,59 9-14 * * * cd /home/matsu/ghq/github.com/matsubo/covid19-daily-tweet && docker-compose run --rm app bundle exec ruby today.rb > /tmp/covid19.log 2>&1
```

## Test

```
% docker-compose run -e TEST=true app bundle exec rspec
```

## Inquiry

https://discord.gg/RaTW47zu3H

## Contribution

- By code, pull requests are welcomed.
- By supplying caffein.

<a href="https://www.buymeacoffee.com/matsubokkuri" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

