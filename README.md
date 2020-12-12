# lapis-community

A drop in, full featured community and comment system for Lapis projects.

[![Build Status](https://travis-ci.org/leafo/lapis-community.svg?branch=master)](https://travis-ci.org/leafo/lapis-community)

Example community: https://itch.io/community

On [itch.io](https://itch.io) every single community, message board, comment
thread is powered by `lapis-community`. It's suitable for managing many
different sub communities with distinct moderators and roles.

## How it works

`lapis-community` provides a collection of *Models* and *Flows* for a database
backed message board. It includes the application layer (aka server side logic)
for interacting with the community using *Flows*. A *Flow* is a class that
groups common functionality into a single module that works on top of the Lapis
action/request interface.

No views are provided (excluding some simple examples) as this is typically the
part of the message board that the implementing site will want to customize.

The following features are included:

* Topics
  * Sticky, Locked, and Archived topics
  * Threaded replies
  * Replies can be HTML or markdown
  * Moderation events (e.g. *Moderator locked this topic*)
  * Mentioning other members with `@`
  * Efficient pagination of very large topics
  * Pending replies -- allow moderator review before allowing a post to be submitted
  * Soft deletion of replies allows for nested replies to be be lost when post is deleted
  * Voting options for replies: up & down, up only, no voting
  * Reply edit history
  * Topics tags (defined on the category)
  * Pinned replies
* Categories (for organizing topics)
  * Can be nested
    * *Directory* categories can be used to organize sub-categories without allowing direct topics
  * Categories can individually have title, description, rules along with enforced restrictions for posts
  * Category options can be inherited from their parents when nested
  * Topic sorting rules per category (by votes, by date, etc.)
* Category groups
  * A way to apply moderation rules across many categories that aren't related in a tree hierarchy
* Moderators
  * Special user permissions granted to moderators
* Post Reporting
* Community stats aggregated per user, per topic, per category
* Visibility tracking
  * Tracks if individual user has yet to see a topic, or topic has unseen replies
* Activity logs
  * Keep an auditable history of all actions on the community
  * Separate moderator logs indexed per category
* Bookmarks
  * A way to save topics for viewing later
* Subscriptions
  * For generating notifications when topics are updated
* Search index
  * Full-text search index on replies and topics
* Blocks
  * An account can block another account to not see their posts
* Bans
  * Moderators can ban accounts from posting or seeing their category

The database schema is managed by the Lapis migration system, using a scoped
set of migrations. Upgrading the database for a new version of
`lapis-community` is as simple as installing the latest version and running the
migration within your own migrations file.


```moonscript
-- migrations.moon
{
  -- ...

  => require("community.schema").run_migrations!
}
```

### Extension interface

No community software perfectly matches the requirements of a particular
website or app. `lapis-community` is built with extensibility in mind. You can
customize how things work by either replacing build-in logic, or appending
additional logic.

> **Example**
> * replacing: using your own models to control who can moderate posts
> * appending: using both the built in moderator system and your own models to control who can moderate posts.

* **Flows** - Since a *Flow* is a class, you can subclass the flow and replace
  methods to change how common operations work
* **Models** - The model loader will attempt to load version of the model from
  your own local models directory before loading the built in one. This can be
  used to either subclass (or replace!) build in models to add additional
  relations and functionality
  * Models have special `on_*_callback` methods can are designed to be replaced
    in a subclass to provide additional functionality in response to events in
    the community

### No presentation layer included

`lapis-community` exposes the models for you to use directly. You can decide
how to format the data within when rendering views, whether that's passing them
down server-side rendered templates, or converting to JSON for client-side
JavaScript templates.

There are flows, however, for fetching the models and preloading all the
necessary data. For example, loading the threaded replies for a particular
topic on a particular page.

## Where it's used

* [itch.io](https://itch.io): global message board, game communities, every single comment thread eg. https://itch.io/community
* [streak.club](https://streak.club): streak message boards

## Documentation

*Coming soon*


