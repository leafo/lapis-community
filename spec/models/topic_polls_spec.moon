
db = require "lapis.db"
factory = require "spec.factory"

import assert_has_queries, sorted_pairs from require "spec.helpers"

import types from require "tableshape"

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

  describe "with poll", ->
    local topic, poll, red_choice, blue_choice

    before_each ->
      topic = factory.Topics!
      poll = TopicPolls\create {
        topic_id: topic.id
        poll_question: "What is your favorite color?"
        start_date: db.raw "date_trunc('seconds', now() at time zone 'utc')"
        end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') + interval '1 day'"
      }
      red_choice = PollChoices\create {
        poll_id: poll.id
        choice_text: "Red"
        position: 1
      }
      blue_choice = PollChoices\create {
        poll_id: poll.id
        choice_text: "Blue"
        position: 2
      }

    it "poll is_open", ->
      poll\update {
        start_date: db.raw "date_trunc('seconds', now() at time zone 'utc') - interval '1 hour'"
        end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') + interval '1 hour'"
      }
      assert.truthy poll\is_open!

      poll\update { end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') - interval '1 minute'" }
      assert.falsy poll\is_open!

    it "deletes poll", ->
      vote1 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: true
      }
      vote2 = PollVotes\create {
        poll_choice_id: blue_choice.id
        user_id: factory.Users!.id
        counted: true
      }

      -- Create another poll to ensure it is not affected by the delete
      other_topic = factory.Topics!
      another_poll = TopicPolls\create {
        topic_id: other_topic.id
        poll_question: "What is your favorite fruit?"
        start_date: db.raw "date_trunc('seconds', now() at time zone 'utc')"
        end_date: db.raw "date_trunc('seconds', now() at time zone 'utc') + interval '1 day'"
      }
      another_choice = PollChoices\create {
        poll_id: another_poll.id
        choice_text: "Apple"
        position: 1
      }
      another_vote = PollVotes\create {
        poll_choice_id: another_choice.id
        user_id: factory.Users!.id
        counted: true
      }

      poll\delete!

      assert.falsy TopicPolls\find poll.id
      assert.falsy PollChoices\find red_choice.id
      assert.falsy PollChoices\find blue_choice.id
      assert.falsy PollVotes\find vote1.id
      assert.falsy PollVotes\find vote2.id

      -- Ensure the new poll and its choices/votes are not affected
      assert.truthy TopicPolls\find another_poll.id
      assert.truthy PollChoices\find another_choice.id
      assert.truthy PollVotes\find another_vote.id

    it "creates poll votes, counted and uncounted", ->
      vote1 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: true
      }
      vote2 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: false
      }

      red_choice\refresh!
      blue_choice\refresh!

      assert.same 1, red_choice.vote_count
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

    it "creates multiple poll votes on same choice with same user", ->
      user = factory.Users!
      vote1 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: user.id
        counted: true
      }
      vote2 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: user.id
        counted: true
      }

      assert.nil vote2, "duplicate vote can not be created"


    it "poll choices recount", ->
      vote1 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: true
      }
      vote2 = PollVotes\create {
        poll_choice_id: blue_choice.id
        user_id: factory.Users!.id
        counted: true
      }

      -- -- clear all the counts
      db.query "update #{db.escape_identifier PollChoices\table_name!} set vote_count = 0"

      red_choice\recount!
      blue_choice\recount!

      assert.same 1, red_choice.vote_count
      assert.same 1, blue_choice.vote_count

      vote1\update counted: false -- this skips set_counted
      red_choice\recount!
      assert.same 0, red_choice.vote_count

    it "deletes poll choice (including all votes votes)", ->
      vote1 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: true
      }
      vote2 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: false
      }
      vote3 = PollVotes\create {
        poll_choice_id: blue_choice.id
        user_id: factory.Users!.id
        counted: true
      }

      red_choice\refresh!
      blue_choice\refresh!
      assert.same 1, red_choice.vote_count
      assert.same 1, blue_choice.vote_count

      assert red_choice\delete!
      assert.is_nil PollChoices\find red_choice.id

      assert.is_nil PollVotes\find vote1.id
      assert.is_nil PollVotes\find vote2.id

      blue_choice\refresh!
      assert.same 1, blue_choice.vote_count

    it "deletes poll votes, both counted and uncounted", ->
      vote1 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: true
      }
      vote2 = PollVotes\create {
        poll_choice_id: red_choice.id
        user_id: factory.Users!.id
        counted: false
      }

      red_choice\refresh!
      blue_choice\refresh!
      assert.same 1, red_choice.vote_count
      assert.same 0, blue_choice.vote_count

      vote1\delete!
      red_choice\refresh!
      blue_choice\refresh!
      assert.same 0, red_choice.vote_count
      assert.same 0, blue_choice.vote_count

      vote2\delete!
      red_choice\refresh!
      blue_choice\refresh!
      assert.same 0, red_choice.vote_count
      assert.same 0, blue_choice.vote_count

    it "poll choice voters", ->
      import preload from require "lapis.db.model"
      users = {
        factory.Users!
        factory.Users!
      }

      v1 = assert red_choice\vote users[1]
      v2 = assert blue_choice\vote users[2]

      voters = {}
      for c in *{red_choice, blue_choice}
        for u in *users
          table.insert voters, c\with_user(u.id)

      preload voters, "vote"

      -- verify all the votes are loaded
      for voter in *voters
        switch "#{voter.poll_choice_id}_#{voter.user_id}"
          when "#{red_choice.id}_#{users[1].id}"
            assert.same v1, voter.vote
          when "#{blue_choice.id}_#{users[2].id}"
            assert.same v2, voter.vote
          else
            assert.nil voter.vote

    describe "vote", ->
      it "allows voting on a single choice poll", ->
        user = factory.Users!
        another_user = factory.Users!
        poll\update { vote_type: TopicPolls.vote_types.single }

        vote1 = red_choice\vote user
        assert.truthy vote1
        assert.same red_choice.id, vote1.poll_choice_id

        other_vote = red_choice\vote another_user
        assert.truthy other_vote
        assert.same red_choice.id, other_vote.poll_choice_id

        red_choice\refresh!
        blue_choice\refresh!
        assert.same 2, red_choice.vote_count
        assert.same 0, blue_choice.vote_count

        vote2 = blue_choice\vote user
        assert.truthy vote2
        assert.same blue_choice.id, vote2.poll_choice_id

        red_choice\refresh!
        blue_choice\refresh!
        assert.same 1, red_choice.vote_count
        assert.same 1, blue_choice.vote_count

        -- Ensure another user's vote is unaffected
        assert.same red_choice.id, other_vote.poll_choice_id
        assert.truthy PollVotes\find other_vote.id

        assert_votes = types.assert types.shape {
          types.partial {
            id: other_vote.id
            poll_choice_id: red_choice.id
            user_id: another_user.id
            counted: true
          }
          types.partial {
            id: vote2.id
            poll_choice_id: blue_choice.id
            user_id: user.id
            counted: true
          }
        }

        assert_votes PollVotes\select "order by id asc"


      it "allows voting on multiple choices poll", ->
        user = factory.Users!
        poll\update { vote_type: TopicPolls.vote_types.multiple }

        vote1 = red_choice\vote user
        assert.truthy vote1
        assert.same red_choice.id, vote1.poll_choice_id

        vote2 = blue_choice\vote user
        assert.truthy vote2
        assert.same blue_choice.id, vote2.poll_choice_id

        red_choice\refresh!
        blue_choice\refresh!
        assert.same 1, red_choice.vote_count
        assert.same 1, blue_choice.vote_count

        assert_votes = types.assert types.shape {
          types.partial {
            id: vote1.id
            poll_choice_id: red_choice.id
            user_id: user.id
            counted: true
          }
          types.partial {
            id: vote2.id
            poll_choice_id: blue_choice.id
            user_id: user.id
            counted: true
          }
        }

        assert_votes PollVotes\select "order by id asc"


