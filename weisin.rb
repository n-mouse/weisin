# encoding: utf-8

require 'sinatra'
require 'uri'
require 'open-uri'
require 'data_mapper'
require 'rufus/scheduler'

DataMapper.setup(:default, "mysql://user:pass@localhost/db_name")

#use Rack::Auth::Basic, "Protected Area" do |username, password|
 # (username == 'username') && (password == 'password')

#end

class Word
  
  include DataMapper::Resource		#Task class is linked to DataMapper 
  property :id,				Serial	#auto-incrementing
  property :name,			String, :required => true
  has n, :changes
    
end

class Change

  include DataMapper::Resource
  property :id,			Serial
  property :status,		String
  property :time,		String #DateTime
  belongs_to :word
  
end
DataMapper.finalize.auto_upgrade!		

module Checks
  def self.check(word)
    word_esc = URI.escape(word)
    file = open(site_name + word_esc + "&Refer")
    text = file.read
    if text["\\u6839\\u636e\\u76f8\\u5173\\u6cd5\\u5f8b\\u6cd5\\u89c4\\u548c\\u653f\\u7b56"]
      @status = "blocked"
    else 
      @status = "unblocked"
    end
  end
end

helpers do
  def check(word)
    Checks.check(word)
  end
end

get '/' do
  @words = Word.all
  erb :index
end

post '/' do

  @word = params[:message]
  status = check(@word)
  w = Word.new
  w.name = @word
  w.save
  s = w.changes.create(:status => status)
  s.time = Time.now.utc
  s.save
  
  redirect to('/')
  
end

get '/result' do
  @words = Word.all
  erb :result
end

get '/:id' do
  @word = Word.get(params[:id])
  erb :delete
end

delete '/:id' do
  Word.get(params[:id]).changes.destroy
  Word.get(params[:id]).destroy
  redirect to('/')
end


configure do
 scheduler = Rufus::Scheduler.start_new
 set :scheduler, scheduler
 scheduler.every '5h' do
  
  Word.all.each do |word|
    status_n = Checks.check(word.name)
    if word.changes.last.status == status_n 
      word.changes << Change.new(:status => status_n, :time => Time.now.utc.strftime("%e %b %Y %H:%m:%S%p").to_s)
    end
    word.save
    secs = *(35..100)
    sleep secs.sample
  end
  
 end
end
