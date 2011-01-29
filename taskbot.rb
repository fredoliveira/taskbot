require 'rubygems'
require 'xmpp4r-simple'
require 'redis'
require 'yaml'

config = open('config.yml') {|f| YAML.load(f) }
@im = Jabber::Simple.new(config['username'], config['password'])
@redis = Redis.new

# push a task into the users's queue
def push(from, task)
	puts "Pushing a task into tasks:#{from}"
	result = @redis.rpush("tasks:#{from}", task)
	say(from, "Task added. There are #{result} tasks in your queue")
end

# pop out a task from the user's queue
def pop(from)
	say(from, @redis.lpop("tasks:#{from}"))
end

# sends the user a list of his tasks
def list(from)
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
def clear(from)
	list(from) # send him the list just in case
	@redis.del("tasks:#{from}")
	say(from, "Queue cleared!")
end

# send user some usage information
def help(from)
	say(from, "Taskbot works as first-in, first-out queue. You add things in, you get things out. It's pretty simple, really (for now, at least).\n\nadd {task} - adds something to your list\nget/pop - gets one item from your list\nlist - lists your entire queue\nclear - cleans up your queue")
end

# add this jabber id to our list of known accounts
def adduser(from)
	if !@redis.sismember("users", from)
		puts "Adding a new user: #{from}"
		@redis.sadd "users", from
		#say(from, "Hi! Try the 'help' command. This is probably unstable for now, by the way.")
	end
end

# send a message to a given user
def say(user, message)
	@im.deliver(user, message)
end

# processes a message
def process(msg)
	from = msg.from.bare.to_s # save our author
	adduser(from) # add the user to our known users list, if he isn't there yet
	body = msg.body # save our message body

	cmd = body.split(" ")[0]
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
			@im.deliver(from, "Unrecognized command")
	end
end

# main application loop
loop do
	for msg in @im.received_messages do 
		if msg.type == :chat
			process(msg)
		end
	end
	sleep 1
end
