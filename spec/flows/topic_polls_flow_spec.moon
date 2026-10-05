import in_request from require "spec.flow_helpers"
import sorted_pairs, capture_queries from require "spec.helpers"

factory = require "spec.factory"
db = require "lapis.db"

import types from require "tableshape"

describe "TopicPollsFlow", ->
  import Users from require "spec.models"
  import Topics, TopicPolls, PollChoices, PollVotes from require "spec.community_models"

  it "validate params", ->
    result = in_request {
      post: {
        poll_question: "What's your favorite color?"
        description: "Choose one of the options below."
        anonymous: "on"
        hide_results: " "
        vote_type: "single"

        "choices[1][choice_text]": "Red"
        "choices[1][position]": "1"
        "choices[2][choice_text]": "Blue"
        "choices[2][description]": "This is a description"
        "choices[2][position]": "2"
        "choices[2][id]": "123"
        "choices[3][choice_text]": "Green"
        "choices[3][position]": "3"
      }
    }, =>
      @flow("topic_polls")\validate_params!

    test_result = types.assert types.shape {
      poll_question: "What's your favorite color?"
      description: "Choose one of the options below."
      anonymous: true
      hide_results: false
      vote_type: TopicPolls.vote_types.single
      choices: types.shape {
        types.shape {
          choice_text: "Red"
          description: types.literal(db.NULL)
          position: 1
        }
        types.shape {
          id: 123
          choice_text: "Blue"
          description: "This is a description"
          position: 2
        }
        types.shape {
          choice_text: "Green"
          description: types.literal(db.NULL)
          position: 3
        }
      }
    }

    test_result result

  it "validate params alt", ->
    result = in_request {
      post: {
        poll_question: "Which do you prefer?"
        vote_type: "multiple"

        "choices[1][choice_text]": "Option A"
        "choices[1][position]": "1"
        "choices[2][choice_text]": "Option B"
        "choices[2][position]": "2"
        "choices[3][choice_text]": "Option C"
        "choices[3][position]": "3"
      }
    }, =>
      @flow("topic_polls")\validate_params!

    test_result = types.assert types.shape {
      poll_question: "Which do you prefer?"
      description: types.literal(db.NULL)
      anonymous: false
      hide_results: false
      vote_type: TopicPolls.vote_types.multiple
      choices: types.shape {
        types.shape {
          choice_text: "Option A"
          description: types.literal(db.NULL)
          position: 1
        }
        types.shape {
          choice_text: "Option B"
          description: types.literal(db.NULL)
          position: 2
        }
        types.shape {
          choice_text: "Option C"
          description: types.literal(db.NULL)
          position: 3
        }
      }
    }

    test_result result

  describe "vote", ->
    local current_user, poll, choice
    before_each ->
      current_user = factory.Users!
      topic = factory.Topics!
      poll = TopicPolls\create {
        topic_id: topic.id
        poll_question: "Vote on this question"
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day' )")
        vote_type: TopicPolls.vote_types.single
      }
      poll\refresh!
      choice = PollChoices\create {
        poll_id: poll.id
        choice_text: "Option A"
        position: 1
      }

    it "creates a vote", ->
      in_request {
        post: {
          choice_id: choice.id
          action: "create"
          poll_version: poll.version
        }
      }, =>
        @current_user = current_user
        @flow("topic_polls")\vote!
        true

      assert PollVotes\find {
        poll_choice_id: choice.id,
        user_id: current_user.id
      }

    it "errors when poll choice is missing", ->
      assert.has_error(
        ->
          in_request {
            post: {
              choice_id: choice.id + 1000
              action: "create"
              poll_version: poll.version
            }
          }, =>
            @current_user = current_user
            @flow("topic_polls")\vote!
            true
        {
          message: {"invalid poll"}
        }
      )

    it "requires poll version to create a vote", ->
      assert.has_error(
        -> in_request {
          post: {
            choice_id: choice.id
            action: "create"
          }
        }, =>
          @current_user = current_user
          @flow("topic_polls")\vote!
          true
        {
          message: {"missing poll version"}
        }
      )

      assert.same 0, PollVotes\count!

    it "rejects a vote for an outdated poll version", ->
      stale_version = poll.version
      poll\update version: db.raw "version + 1"

      assert.has_error(
        -> in_request {
          post: {
            choice_id: choice.id
            action: "create"
            poll_version: stale_version
          }
        }, =>
          @current_user = current_user
          @flow("topic_polls")\vote!
          true
        {
          message: {"this poll has changed since you loaded it, please review it and vote again"}
        }
      )

      assert.same 0, PollVotes\count!

    it "deletes an existing vote", ->
      assert PollVotes\create {
        poll_choice_id: choice.id
        user_id: current_user.id
        counted: true
      }

      in_request {
        post: {
          choice_id: choice.id
          action: "delete"
        }
      }, =>
        @current_user = current_user
        @flow("topic_polls")\vote!
        true

      vote = PollVotes\find {
        poll_choice_id: choice.id,
        user_id: current_user.id
      }
      assert not vote

    it "fails to create a vote on a closed poll", ->
      poll\update {
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' - interval '1 day' )")
      }

      assert.has_error(
        -> in_request {
          post: {
            choice_id: choice.id
            action: "create"
            poll_version: poll.version
          }
        }, =>
          @current_user = current_user
          @flow("topic_polls")\vote!
          true
        {
          message: {"poll is closed"}
        }
      )

    it "prevents deleting a vote on a closed poll", ->
      poll\update {
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' - interval '1 day' )")
      }
      assert PollVotes\create {
        poll_choice_id: choice.id
        user_id: current_user.id
        counted: true
      }

      assert.has_error(
        -> in_request {
          post: {
            choice_id: choice.id
            action: "delete"
          }
        }, =>
          @current_user = current_user
          @flow("topic_polls")\vote!
          true
        {
          message: {"poll is closed"}
        }
      )

      -- vote should still exist
      vote = PollVotes\find {
        poll_choice_id: choice.id,
        user_id: current_user.id
      }
      assert vote

  describe "set choices", ->
    sorted_pairs!

    local current_user
    before_each ->
      current_user = factory.Users!

    it "sets choices on poll with no choices", ->
      topic = factory.Topics!
      poll = TopicPolls\create {
        topic_id: topic.id
        poll_question: "Some question..."
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day' )")
        vote_type: TopicPolls.vote_types.single
      }

      choices = {
        { choice_text: "Option A", position: 1 }
        { choice_text: "Option B", position: 2, description: "hello world"}
      }

      in_request {}, =>
        @current_user = current_user
        @flow("topic_polls")\set_choices poll, choices

      poll_choices = PollChoices\select "where ? order by position asc", db.clause {
        poll_id: poll.id
      }

      test_choices = types.assert types.shape {
        types.partial {
          poll_id: poll.id,
          choice_text: "Option A",
          position: 1
        }
        types.partial {
          poll_id: poll.id,
          choice_text: "Option B",
          position: 2,
          description: "hello world"
        }
      }

      test_choices poll_choices

    it "sets choices on poll with existing choices", ->
      topic = factory.Topics!
      poll = TopicPolls\create {
        topic_id: topic.id
        poll_question: "Some question..."
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day' )")
        vote_type: TopicPolls.vote_types.single
      }

      -- Existing choices
      existing_choice_1 = PollChoices\create {
        poll_id: poll.id
        choice_text: "Old Option A"
        position: 1
      }

      existing_choice_2 = PollChoices\create {
        poll_id: poll.id
        choice_text: "Old Option B"
        position: 2
      }

      queries = in_request {}, =>
        @current_user = current_user
        capture_queries ->
          @flow("topic_polls")\set_choices poll, {
            {
              id: existing_choice_1.id
              choice_text: "Updated Option A"
              position: 1
            }
            {
              choice_text: "New Option C",
              position: 3
            }
          }

      poll_choices = PollChoices\select "where ? order by position asc", db.clause {
        poll_id: poll.id
      }

      test_choices = types.assert types.shape {
        types.partial {
          id: existing_choice_1.id
          poll_id: poll.id,
          choice_text: "Updated Option A",
          position: 1
        }
        types.partial {
          poll_id: poll.id,
          choice_text: "New Option C",
          position: 3
        }
      }

      test_choices poll_choices

      -- Ensure the old choice that was not updated is deleted
      assert.nil PollChoices\find existing_choice_2.id

      -- sanity check that the queries are correct
      updates = [q for q in *queries when q\match "^UPDATE"]
      deletes = [q for q in *queries when q\match "^DELETE"]
      inserts = [q for q in *queries when q\match "^INSERT"]

      assert.same 1, #updates, 1
      assert.truthy updates[1]\match "UPDATE \"community_poll_choices\" SET \"choice_text\" = 'Updated Option A', \"position\" = 1, \"updated_at\" = '.-' WHERE \"id\" = #{existing_choice_1.id}"
      assert.same #deletes, 2
      assert.same deletes[1], "DELETE FROM \"community_poll_choices\" WHERE \"id\" = #{existing_choice_2.id}"
      assert.same deletes[2], "DELETE FROM \"community_poll_votes\" WHERE (poll_choice_id = #{existing_choice_2.id})"
      assert.same #inserts, 1
      assert.truthy inserts[1]\match "^INSERT INTO \"community_poll_choices\" %(\"choice_text\", \"created_at\", \"poll_id\", \"position\", \"updated_at\"%) VALUES %('New Option C', '.-', #{poll.id}, 3, '.-'%) RETURNING \"id\""

  describe "set_poll", ->
    local topic
    before_each ->
      topic = factory.Topics!

    it "creates a poll for topic without poll", ->
      poll_params = {
        poll_question: "What is your favorite color?"
        description: "Choose one of the options below."
        anonymous: true
        hide_results: false
        vote_type: TopicPolls.vote_types.single
        choices: {
          { choice_text: "Red", position: 1 }
          { choice_text: "Blue", position: 2 }
        }
      }

      poll = in_request {}, =>
        @flow("topic_polls")\set_poll topic, poll_params

      assert.truthy poll
      assert.equal poll.poll_question, poll_params.poll_question
      assert.equal poll.description, poll_params.description
      assert.equal poll.anonymous, poll_params.anonymous
      assert.equal poll.hide_results, poll_params.hide_results
      assert.equal poll.vote_type, poll_params.vote_type

      poll_choices = PollChoices\select "where ? order by position asc", db.clause {
        poll_id: poll.id
      }

      test_choices = types.assert types.shape {
        types.partial {
          poll_id: poll.id,
          choice_text: "Red",
          position: 1
        }
        types.partial {
          poll_id: poll.id,
          choice_text: "Blue",
          position: 2
        }
      }

      test_choices poll_choices


    it "updates poll for topic with existing poll", ->
      topic = factory.Topics!

      poll = TopicPolls\create {
        topic_id: topic.id
        poll_question: "Initial question"
        description: "Initial description"
        anonymous: false
        hide_results: true
        vote_type: TopicPolls.vote_types.single
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day' )")
      }

      existing_choice = PollChoices\create {
        poll_id: poll.id
        choice_text: "Initial Option A"
        position: 1
      }


      poll_params = {
        poll_question: "Updated question"
        description: "Updated description"
        anonymous: true
        hide_results: false
        vote_type: TopicPolls.vote_types.multiple
        choices: {
          { id: existing_choice.id, choice_text: "Updated Option A", position: 1 }
          { choice_text: "New Option B", position: 2 }
        }
      }

      in_request {}, =>
        @flow("topic_polls")\set_poll topic, poll_params

      poll\refresh!

      assert.equal poll.poll_question, poll_params.poll_question
      assert.equal poll.description, poll_params.description
      assert.equal poll.anonymous, poll_params.anonymous
      assert.equal poll.hide_results, poll_params.hide_results
      assert.equal poll.vote_type, poll_params.vote_type

      poll_choices = PollChoices\select "where ? order by position asc", db.clause {
        poll_id: poll.id
      }

      test_choices = types.assert types.shape {
        types.partial {
          id: existing_choice.id
          poll_id: poll.id,
          choice_text: "Updated Option A",
          position: 1
        }
        types.partial {
          poll_id: poll.id,
          choice_text: "New Option B",
          position: 2
        }
      }

      test_choices poll_choices

    it "does not change end_date when updating existing poll", ->
      poll = TopicPolls\create {
        topic_id: topic.id
        poll_question: "Closed question"
        vote_type: TopicPolls.vote_types.single
        start_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' - interval '2 days')")
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' - interval '1 day')")
      }

      original_end_date = poll.end_date
      assert.falsy poll\is_open!

      in_request {}, =>
        @flow("topic_polls")\set_poll topic, {
          poll_question: "Edited question"
          vote_type: TopicPolls.vote_types.single
          choices: {
            { choice_text: "Only option" }
          }
        }

      poll\refresh!
      assert.equal "Edited question", poll.poll_question
      assert.equal original_end_date, poll.end_date
      assert.falsy poll\is_open!

  describe "locked_poll_changes", ->
    local poll, choice_a, choice_b

    before_each ->
      poll = TopicPolls\create {
        topic_id: factory.Topics!.id
        poll_question: "Question?"
        vote_type: TopicPolls.vote_types.single
        anonymous: true
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day')")
      }

      choice_a = PollChoices\create poll_id: poll.id, choice_text: "A", position: 1
      choice_b = PollChoices\create poll_id: poll.id, choice_text: "B", position: 2

    -- params as they would come out of validate_params_shape
    unchanged_params = ->
      {
        poll_question: "Question?"
        description: db.NULL
        anonymous: true
        hide_results: false
        vote_type: TopicPolls.vote_types.single
        choices: {
          { id: choice_a.id, choice_text: "A" }
          { id: choice_b.id, choice_text: "B" }
        }
      }

    -- in_request asserts a truthy return, so the result is wrapped
    locked_poll_changes = (params) ->
      unpack in_request {}, =>
        { @flow("topic_polls")\locked_poll_changes poll, params }

    it "allows any change when poll has no votes", ->
      params = unchanged_params!
      params.poll_question = "Different?"
      params.anonymous = false
      params.choices = { { choice_text: "C" } }
      assert.is_nil locked_poll_changes params

    describe "with votes", ->
      before_each ->
        choice_a\vote factory.Users!

      it "returns nil for unchanged poll", ->
        assert.is_nil locked_poll_changes unchanged_params!

      it "allows non-locked changes", ->
        params = unchanged_params!
        params.description = "New description"
        params.hide_results = true
        params.anonymous = true
        table.insert params.choices, { choice_text: "C" }
        assert.is_nil locked_poll_changes params

      it "detects choice description change", ->
        params = unchanged_params!
        params.choices[1].description = "about A"
        assert.same {"choice description"}, locked_poll_changes params

      it "allows enabling anonymous", ->
        poll\update anonymous: false
        assert.is_nil locked_poll_changes unchanged_params!

      it "detects every locked change", ->
        params = unchanged_params!
        params.poll_question = "Different?"
        params.vote_type = TopicPolls.vote_types.multiple
        params.anonymous = false
        params.choices = {
          { id: choice_a.id, choice_text: "A changed" }
        }

        assert.same {
          "question", "vote type", "choice text", "removed choice", "anonymous"
        }, locked_poll_changes params

      it "treats choice ids from another poll as removal", ->
        other_choice = PollChoices\create poll_id: poll.id + 1000, choice_text: "X"
        params = unchanged_params!
        params.choices[2] = { id: other_choice.id, choice_text: "B" }

        assert.same {"removed choice"}, locked_poll_changes params

  describe "poll version", ->
    local topic, poll, choice_a, choice_b

    before_each ->
      topic = factory.Topics!
      poll = TopicPolls\create {
        topic_id: topic.id
        poll_question: "Question?"
        vote_type: TopicPolls.vote_types.single
        end_date: db.raw("date_trunc('second', now() AT TIME ZONE 'utc' + interval '1 day')")
      }
      poll\refresh!

      choice_a = PollChoices\create poll_id: poll.id, choice_text: "A", position: 1
      choice_b = PollChoices\create poll_id: poll.id, choice_text: "B", position: 2

    edit_poll = (fn) ->
      params = {
        poll_question: "Question?"
        description: "Description"
        anonymous: true
        hide_results: false
        vote_type: TopicPolls.vote_types.single
        choices: {
          { id: choice_a.id, choice_text: "A" }
          { id: choice_b.id, choice_text: "B" }
        }
      }

      fn params if fn

      in_request {}, =>
        @flow("topic_polls")\set_poll topic, params

      poll\refresh!
      poll.version

    it "starts at 1", ->
      assert.same 1, poll.version

    it "doesn't change for description and display settings", ->
      assert.same 1, edit_poll (p) ->
        p.description = "Other description"
        p.hide_results = true
        p.anonymous = false

    it "increments when question changes", ->
      assert.same 2, edit_poll (p) -> p.poll_question = "Other?"

    it "increments when vote type changes", ->
      assert.same 2, edit_poll (p) -> p.vote_type = TopicPolls.vote_types.multiple

    it "increments when choice text changes", ->
      assert.same 2, edit_poll (p) -> p.choices[2].choice_text = "B2"

    it "increments when choice description changes", ->
      assert.same 2, edit_poll (p) -> p.choices[1].description = "about A"

    it "increments when choice is added", ->
      assert.same 2, edit_poll (p) -> table.insert p.choices, { choice_text: "C" }

    it "increments when choice is removed", ->
      assert.same 2, edit_poll (p) -> table.remove p.choices

    it "increments on each content edit", ->
      edit_poll (p) -> p.poll_question = "Second?"
      assert.same 3, edit_poll (p) -> p.poll_question = "Third?"

  describe "set_poll_dates", ->
    date = require "date"

    iso = (d) -> d\fmt "%Y-%m-%dT%H:%M:%SZ"
    from_now = (seconds) -> date(true)\addseconds seconds

    -- in_request asserts a truthy return, so the result is wrapped
    set_poll_dates = (params) ->
      unpack in_request {}, =>
        { @flow("topic_polls")\set_poll_dates params }

    span = (a, b) -> date.diff(date(b), date(a))\spanseconds!

    it "defaults to starting now and lasting one day", ->
      params = {}
      assert.true set_poll_dates params
      assert.true math.abs(span(date(true)\fmt("%Y-%m-%d %H:%M:%S"), params.start_date)) <= 2
      assert.same 60 * 60 * 24, span params.start_date, params.end_date

    it "keeps a future start date", ->
      start = from_now 60 * 60 * 24 * 2
      params = { start_date: start\fmt "%Y-%m-%d %H:%M:%S" }
      assert.true set_poll_dates params
      assert.same start\fmt("%Y-%m-%d %H:%M:%S"), params.start_date
      assert.same 60 * 60 * 24, span params.start_date, params.end_date

    it "moves a past start date to now", ->
      params = {
        start_date: from_now(-60 * 60 * 24)\fmt "%Y-%m-%d %H:%M:%S"
        end_date: from_now(60 * 60 * 5)\fmt "%Y-%m-%d %H:%M:%S"
      }
      assert.true set_poll_dates params
      assert.true math.abs(span(date(true)\fmt("%Y-%m-%d %H:%M:%S"), params.start_date)) <= 2

    it "rejects a poll shorter than the minimum", ->
      assert.same {nil, "poll must be open for at least 1 hour(s)"}, {set_poll_dates {
        end_date: from_now(60 * 30)\fmt "%Y-%m-%d %H:%M:%S"
      }}

    it "rejects an end date before the start date", ->
      assert.same {nil, "poll must be open for at least 1 hour(s)"}, {set_poll_dates {
        start_date: from_now(60 * 60 * 10)\fmt "%Y-%m-%d %H:%M:%S"
        end_date: from_now(60 * 60 * 5)\fmt "%Y-%m-%d %H:%M:%S"
      }}

    it "rejects a start date too far in the future", ->
      assert.same {nil, "poll can't start more than 30 days from now"}, {set_poll_dates {
        start_date: from_now(60 * 60 * 24 * 31)\fmt "%Y-%m-%d %H:%M:%S"
      }}

    it "rejects a poll longer than the maximum", ->
      assert.same {nil, "poll can't be open for more than 30 days"}, {set_poll_dates {
        end_date: from_now(60 * 60 * 24 * 31)\fmt "%Y-%m-%d %H:%M:%S"
      }}

    it "validates dates through validate_params", ->
      start = from_now 60 * 60
      finish = from_now 60 * 60 * 25

      result = in_request {
        post: {
          poll_question: "When?"
          start_date: iso start
          end_date: iso finish
          "choices[1][choice_text]": "Now"
        }
      }, =>
        @flow("topic_polls")\validate_params!

      assert.same start\fmt("%Y-%m-%d %H:%M:%S"), result.start_date
      assert.same finish\fmt("%Y-%m-%d %H:%M:%S"), result.end_date

      assert.has_error(
        -> in_request {
          post: {
            poll_question: "When?"
            end_date: "tomorrow"
            "choices[1][choice_text]": "Now"
          }
        }, =>
          @flow("topic_polls")\validate_params!
        {
          message: {"end_date: expected empty, or ISO 8601 date with timezone"}
        }
      )
