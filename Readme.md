# Taskbot

Taskbot is a simple XMPP-based bot that keeps track of a list of your
tasks. Taskbot currently works on top of Redis (using a combination of
linked-lists and sets) to provide its functionality. As such, the same
kind of considerations on persistence that apply to redis, also apply to
Taskbot. Keep that in mind if you want to run this in production. The
system, running on Redis' default configuration will self-regulate to
persist automatically depending on activity.

## Configuring Taskbot

Create a `config.yml` file (based on the example) and add a username and
password to it for a given xmpp account (you can create one at
jabber.org, or use a Google Account, if you'd like).  

Run your redis-server instance if it isn't yet and boot up taskbot by
running `ruby taskbot.rb`. That's pretty much it.

## Taskbot commands

Taskbot is quite rudimentary at this point, but it implmenets the
following commands to manage your task-list:

* `add my task` - Adds 'my task' to your task queue
* `put my task` - Alias to 'add'
* `get` - Gets a task from the queue. It also pops the task out
* `pop` - Alias for 'get'
* `list` - Returns a dump of your first 10 elements in the queue
* `clear` - Resets your queue

## Internals

Taskbot is multi-user, meaning that it can be used by a virtually
unlimited number of people at the same time. Tasks for each user are
stored in a redis linked list named `tasks:jabberid`. A list of known
users is kept in the set 'users', which can be polled from Redis if
necessary. 
