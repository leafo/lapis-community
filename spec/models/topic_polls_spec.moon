
db = require "lapis.db"
factory = require "spec.factory"

import assert_has_queries, sorted_pairs from require "spec.helpers"

describe "models.topics", ->
  sorted_pairs!

  import Users from require "spec.models"

  import Topics, TopicPolls, PollChoices, PollVotes from require "spec.community_models"

  it "should create a poll", ->
    topic = factory.Topics!
    poll = TopicPolls\create {
      topic_id: topic.id
      poll_question: "What is your favorite color?"
      start_date: db.raw "date_trunc('seconds', now() at time zone 'utc')"
      end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') + interval '1 day'"
    }
    assert.truthy poll.id

    PollChoices\create {
      poll_id: poll.id
      choice_text: "Red"
      position: 1
    }
    PollChoices\create {
      poll_id: poll.id
      choice_text: "Blue"
      position: 2
    }
    PollChoices\create {
      poll_id: poll.id
      choice_text: "Green"
      position: 3
    }

    choices = poll\get_poll_choices!

    assert.same 3, #choices
    assert.same "Red", choices[1].choice_text
    assert.same "Blue", choices[2].choice_text
    assert.same "Green", choices[3].choice_text

  it "poll is_open", ->
    topic = factory.Topics!
    poll = TopicPolls\create {
      topic_id: topic.id
      poll_question: "What is your favorite color?"
      start_date: db.raw "date_trunc('seconds', now() at time zone 'utc') - interval '1 hour'"
      end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') + interval '1 hour'"
    }
    assert.truthy poll\is_open!

    poll\update { end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') - interval '1 minute'" }
    assert.falsy poll\is_open!


  it "creates poll votes, counted and uncounted", ->
    topic = factory.Topics!
    poll = TopicPolls\create {
      topic_id: topic.id
      poll_question: "What is your favorite color?"
      start_date: db.raw "date_trunc('seconds', now() at time zone 'utc')"
      end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') + interval '1 day'"
    }
    choice1 = PollChoices\create {
      poll_id: poll.id
      choice_text: "Red"
      position: 1
    }

    choice2 = PollChoices\create {
      poll_id: poll.id
      choice_text: "Blue"
      position: 2
    }

    vote1 = PollVotes\create {
      poll_choice_id: choice1.id
      user_id: factory.Users!.id
      counted: true
    }
    vote2 = PollVotes\create {
      poll_choice_id: choice1.id
      user_id: factory.Users!.id
      counted: false
    }

    red_choice, blue_choice = unpack poll\get_poll_choices!

    assert.same "Red", red_choice.choice_text
    assert.same 1, red_choice.vote_count

    assert.same "Blue", blue_choice.choice_text
    assert.same 0, blue_choice.vote_count

    vote1\set_counted false
    red_choice\refresh!
    blue_choice\refresh!
    assert.same 0, red_choice.vote_count
    assert.same 0, blue_choice.vote_count

    vote1\set_counted true
    red_choice\refresh!
    blue_choice\refresh!
    assert.same 1, red_choice.vote_count
    assert.same 0, blue_choice.vote_count

    -- test no-op set counted, where counted is already the same value
    vote1\set_counted true
    red_choice\refresh!
    blue_choice\refresh!
    assert.same 1, red_choice.vote_count
    assert.same 0, blue_choice.vote_count

    vote2\set_counted false
    red_choice\refresh!
    blue_choice\refresh!
    assert.same 1, red_choice.vote_count
    assert.same 0, blue_choice.vote_count


  it "poll choices recount", ->
    topic = factory.Topics!
    poll = TopicPolls\create {
      topic_id: topic.id
      poll_question: "What is your favorite color?"
      start_date: db.raw "date_trunc('seconds', now() at time zone 'utc')"
      end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') + interval '1 day'"
    }
    choice1 = PollChoices\create {
      poll_id: poll.id
      choice_text: "Red"
      position: 1
    }

    choice2 = PollChoices\create {
      poll_id: poll.id
      choice_text: "Blue"
      position: 2
    }

    vote1 = PollVotes\create {
      poll_choice_id: choice1.id
      user_id: factory.Users!.id
      counted: true
    }
    vote2 = PollVotes\create {
      poll_choice_id: choice2.id
      user_id: factory.Users!.id
      counted: true
    }

    -- -- clear all the counts
    db.query "update #{db.escape_identifier PollChoices\table_name!} set vote_count = 0"

    choice1\recount!
    choice2\recount!

    assert.same 1, choice1.vote_count
    assert.same 1, choice2.vote_count

    vote1\update counted: false -- this skips set_counted
    choice1\recount!
    assert.same 0, choice1.vote_count


