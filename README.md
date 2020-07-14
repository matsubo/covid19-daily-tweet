# covid19-daily-tweet

![Ruby](https://github.com/matsubo/covid19-daily-tweet/workflows/Ruby/badge.svg)

- [新型コロナウイルス感染症対策に関するオープンデータ項目定義書](https://docs.google.com/spreadsheets/d/1fJtqxqh_4OuUwq2LQ_WRx23fwcEB4hNL/edit#gid=1874865803)フォーマットで提供されている（またはプログラムにとって可読性の高いファイルが提供されている）都道府県のデータを30分に1回クロールして新規感染者がでた場合はTweetします。
- pull-requestやissueの内容の解決はウェルカムです。

## Setup

```
% cp twitter.yaml.template twitter.yaml
% vi twitter.yaml
% docker-compose run app bundle
```

## Run

Manually
```
% docker-compose run app bundle exec ruby main.rb
```

Damon in background
```
% docker-compose up -d 
```


## Test

```
% docker-compose run -e TEST=true app bundle exec rspec
```



## License

TBD

## Screenshot

![image](https://user-images.githubusercontent.com/98103/87386885-813da800-c5dc-11ea-831d-bfa5371e9509.png)

