require 'rubygems'
require 'xmpp4r'
require 'redis'
require 'yaml'

class Taskbot
	def self.start
		# Jabber::debug = true
		config = open('config.yml') {|f| YAML.load(f) }
		@im = Jabber::Client.new(config['username'])

		@redis = Redis.new

		begin
			@im.on_exception do |error,| print(error) end
			@im.add_message_callback do |msg|
				if msg.type == :chat
					Taskbot.process(msg)
				end
			end
			@im.connect
			@im.auth(config['password'])
			Thread.new {
				while @im.is_connected? do
					@im.send(Jabber::Presence.new)
					sleep 60
				end
			}
			Thread.stop
		rescue Exception => error
			print error.to_s
		end
	end

	# push a task into the users's queue
	def self.push(from, task)
		puts "Pushing a task into tasks:#{from}"
		result = @redis.rpush("tasks:#{from}", task)
		say(from, "Task added. There are #{result} tasks in your queue")
	end

	# pop out a task from the user's queue
	def self.pop(from)
		say(from, @redis.lpop("tasks:#{from}"))
	end

	# sends the user a list of his tasks
	def self.list(from)
		length = @redis.llen("tasks:#{from}")
		if length > 10
			say(from, "You have over 10 tasks on your queue. Limiting output to 10")
			tasks = @redis.lrange("tasks:#{from}", 0, 9)		
		else
			tasks = @redis.lrange("tasks:#{from}", 0, -1)
		end

		output = ""
		tasks.each_with_index do |task, i| 
			output << "#{i+1}: #{task} \n"
		end
		say(from, output)
	end

	# clean up a user's queue
	def self.clear(from)
		list(from) # send them the list just in case
		@redis.del("tasks:#{from}")
		say(from, "Queue cleared!")
	end

	# send user some usage information
	def self.help(from)
		say(from, "Taskbot works as first-in, first-out queue. You add things in, you get things out. It's pretty simple, really (for now, at least).\n\nadd {task} - adds something to your list\nget/pop - gets one item from your list\nlist - lists your entire queue\nclear - cleans up your queue")
	end

	# add this jabber id to our list of known accounts
	def self.adduser(from)
		if !@redis.sismember("users", from)
			puts "Adding a new user: #{from}"
			@redis.sadd "users", from
			#say(from, "Hi! Try the 'help' command. This is probably unstable for now, by the way.")
		end
	end

	# send a message to a given user
	def self.say(user, message)
		msg = Jabber::Message.new(user)
		msg.type = :chat
		msg.body = message
		@im.send(msg)
	end

	# processes a message
	def self.process(msg)
		from = msg.from.bare.to_s # save our author
		adduser(from) # add the user to our known users list, if he isn't there yet
		body = msg.body || "" # save our message body

		cmd = body.split(" ")[0] or return
		l = cmd.length + 1
		body = body[l..-1] # grab everything except the command

		case cmd
			when "help" then
				help(from)
			when "add" then
				push(from, body)
			when "push" then
				push(from, body)
			when "get" then
				pop(from)
			when "pop" then 
				pop(from)
			when "list" then
				list(from)
			when "clear" then
				clear(from)
			else
				say(from, "Unrecognized command")
		end
	end
end

Taskbot.start
