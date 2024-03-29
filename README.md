# lapis-community

A drop in, full featured community and comment system for Lapis projects.

![test](https://github.com/leafo/lapis-community/workflows/test/badge.svg)

Example community: https://itch.io/community

On [itch.io](https://itch.io) every single community, message board, comment
thread is powered by `lapis-community`. It's suitable for managing many
different sub communities with distinct moderators and roles.

## Note on versioning

This project uses a 3 part version: `X.X.X`, which can be interpreted as
`{major}.{schema}.{minor}`.

The *schema* version number is incremented if the database schema is updated in
some way. This update will include a corresponding database migration that
matches the number. These changes may also include changes to the code
interfaces. Read the change-log for notes about how to work with the update.

In your own Lapis app, you can assert that migrations up to a certain version
are run by writing a migration that looks like: (where 42 is an example schema version)

```moonscript
=> require("community.schema").run_migrations 42
```

The *minor* version number is incremented for bug fixes/minor changes that will
continue to operate on the same schema. No significant changes to code
interfaces are made.

The *major* version will only be incremented if the project is rewritten or
there are substantial breaking changes such that require to concurrent versions
of the library.

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
  * Post content can be HTML or markdown
  * Moderation events (e.g. *Moderator locked this topic*)
  * Mentioning other accounts with `@`
  * Efficient pagination of very large topics
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
  * Categories can be configured to be "members-only"
    * Membership status is inherited by the category hierarchy, so nested categories automatically will grant access to a user if they are a member of a higher up category
* Pending Posts
  * New topics or posts can be marked as pending, and will need to be approved by a moderator before they are published
  * Moderators can set global rules on categories to force every post to go into pending
  * Implementing community can define own rules around what posts are put into pending queue, eg. from spam detector
* Category groups
  * A way to apply moderation rules across many categories that aren't related in a tree hierarchy
* Moderators
  * A category can define a list of special user accounts that have extended permissions over the posts & topics in that category
  * Moderators will have control over the entire category hierarchy below where their role is defined, and a moderator can be created at any level of the hierarchy
  * Moderators can not add new moderators unless they are marked as "admin" moderator
  * Moderator must approve the request to become moderator, to prevent random user from adding others as moderators indiscriminately
* Post Reporting
  * Any user can create a report on a post if they feel it violates the community rules in some way
  * The report will make a copy of the post, in case the post is deleted, so admins & moderators can still review that account for violation
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
* Warnings
  * A warning can be created on an account to either block or force all posts to go into pending for some duration
  * The warning contains a message about what rule was violated
  * The warning duration only starts after it has been viewed for the first time

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


