require 'net/http'

CACHE = ActiveSupport::Cache::FileStore.new(Rails.root.join('cache'))

namespace :import do
  def get_url(url)
    CACHE.fetch(url) do
      HTTParty.get(url).body
    end
  end

  def label_for_url(url)
    url.match(/swapi.co\/api\/([^\/]+)\/(\d)/)[1].classify
  end

  def create_record(record)
    label = label_for_url(record['url'])

    attributes = record.each_with_object({}) do |(key, value), attributes|
      if value.is_a?(String) && (!value.match(/^http/) || key == 'url')
        attributes[key] = value
      end
    end

    Neo4j::Session.query.create(label => attributes).exec
  end

  def relationship_query_for_url(source_url, target_url, type)
    Neo4j::Session.query.match(source: {url: source_url}, target: {url: target_url}).create("source-[:`#{type}`]->target")
  end

  def create_relationships(record)
    record.each do |key, value|
      if value.is_a?(Array)
        value.each do |v|
          relationship_query_for_url(record['url'], v, key).exec
        end
      elsif value.to_s.match(/^http/)
        relationship_query_for_url(record['url'], value, key).exec
      end
    end
  end

  def for_each_record
    types = %w{ people planets films species vehicles starships }

    types.each do |type|
      current_url = "http://swapi.co/api/#{type}/"

      while current_url
        data = JSON.parse(get_url(current_url))

        data['results'].each do |result|
          yield result
        end
        

        if data['next']
          current_url = data['next']
        else
          current_url = nil
        end
      end
    end


  end

  task api: :environment do

    Neo4j::Session.query.match(:n).optional_match('n-[r]-()').delete(:n, :r).exec

    for_each_record do |record|
      putc '.'
      create_record(record)
    end

    for_each_record do |record|
      putc '-'
      create_relationships(record)
    end


  end
end
