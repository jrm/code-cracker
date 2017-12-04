#!/usr/bin/env ruby
require 'io/console'
require 'net/telnet'

BASE = 'A'.ord
SIZE = 'Z'.ord - BASE + 1

class Keyword

  def initialize(text)
    @vals = text.upcase.gsub(/[^A-Z]/, '').chars.map{|c| c.ord - BASE}
    puts @vals.inspect
    @index = -1
  end

  def next
    @index = @index == (@vals.size - 1) ? 0 : @index + 1
    return @vals[@index]
  end

  def previous
    @index = @index <= 1 ? 0 : @index - 1
    return @vals[@index]
  end

end

class Screen

  def initialize
    @lcd = Net::Telnet.new('Host' => '127.0.0.1', 'Port' => 13669, 'Telnetmode' => false, 'Timeout' => false)
    @lcd.puts('hello')
    @lcd.puts('screen_add s1')
    @lcd.puts('screen_set s1 -priority 1')
    @lcd.puts('screen_set s1 -heartbeat off')
    @lcd.puts('widget_add s1 top string')
    @lcd.puts('widget_add s1 bottom string')
    reset_pages
    run!
  end

  def close
    @lcd && @lcd.close
  end

  def reset_pages
    @pages = [ [[],[]] ]
    @page_index = 0
    @page = @pages[@page_index]
    @message = []
  end

  def enter
    @pages.push([[],[]])
    @page_index = @pages.size - 1
    @page = @pages[@page_index]
  end

  def up
    @page_index = [0,@page_index - 1].max
    @page = @pages[@page_index]
  end

  def down
    @page_index = [@pages.size - 1,@page_index + 1].min
    @page = @pages[@page_index]
  end

  def delete
    @page[0].pop
    @page[1].pop
  end

  def append(arr)
    enter if @page[0].size > 15
    @page[0].push(arr[0])
    @page[1].push(arr[1])
  end

  def write_t(text)
    #@lcd.puts("widget_set s1 top 1 1 {text}")
    @message[0] = text
  end

  def write_b(text)
    #@lcd.puts("widget_set s1 bottom 1 1 {text}")
    @message[1] = text
  end


  def run!
    @runner = Thread.new do
      while true do
        t_str = (@message && @message[0]) || @page[0].join
        b_str = (@message && @message[1]) || @page[1].join
        @lcd.puts("widget_set s1 top 1 1 {#{t_str}}")
        @lcd.puts("widget_set s1 bottom 1 2 {#{b_str}}")
        sleep 0.1
      end
    end
  end

  def stop
    @runner && @runner.kill
  end

end

def read_char
  STDIN.echo = false
  STDIN.raw!
  input = STDIN.getc.chr
  if input == "\e" then
    input << STDIN.read_nonblock(3) rescue nil
    input << STDIN.read_nonblock(2) rescue nil
  end
ensure
  STDIN.echo = true
  STDIN.cooked!
  return input
end

def start
  @screen.write_t("   Welcome to")
  @screen.write_b("  Code Cracker!")
  sleep 3
end

def quit
  @screen.write_t("Goodbye...")
  @screen.write_b("                ")
  sleep 3
  exit 0
end

def set_mode
  @screen.write_t("Encrypt = E")
  @screen.write_b("Decrypt = D")
  mode = nil
  while true do
    input = read_char
    case input
      when "\e"
        quit
      when "\u0003"
        quit
      when /e|d/
        mode = input
      when /\r/
        return mode
    else
    end
  end
end

def set_keyword
  keyword = []
  @screen.write_b("                ")
  @screen.write_t("Mode: #{@mode && @mode == 'e' ? 'Encrypt' : 'Decrypt'}")
  @screen.write_b("Keyword:#{keyword.join}")
  while true do
    input = read_char
    case input
      when "\e"
        quit
      when "\u0003"
        quit
      when /[A-Za-z]/
        keyword << input.upcase
        @screen.write_b("Keyword:#{keyword.join}")
      when /\r/
        return Keyword.new(keyword.join)
    else
    end
  end
end

def process
  @screen = Screen.new
  start
  @mode = set_mode
  @keyword = set_keyword
  @screen.reset_pages

  while true do
    input = read_char
    puts input.inspect
    case input
      when "\e"
        #escape
        @screen.close
        process
      when "\u0003"
        #ctl-c
        quit
      when "\r"
        #enter
        @screen.enter
      when "\e[A"
        #back
        @screen.up
      when "\e[B"
        #fwd
        @screen.down
      when "\177"
        @keyword.previous
        @screen.delete
      when /[\s\,\.]/
        @screen.append([input,input])
      when /[A-Za-z]/
        text = input.upcase
        key = @keyword.next
        conv = ((text.ord - BASE).send(@mode == 'e' ? :+ : :-, key) % SIZE + BASE).chr
        puts "Text: #{text}, Key: #{key}, Enc: #{conv}"
        @screen.append([text,conv])
      else
    end
  end
end

require "open3"

Open3.popen3('/usr/sbin/LCDd -s 1 -f -c /etc/LCDd.conf') do |stdin, stdout, stderr| 
  sleep 5
  process
end
