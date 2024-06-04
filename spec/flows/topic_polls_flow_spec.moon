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
      anonymous: true
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
        }
      }, =>
        @current_user = current_user
        @flow("topic_polls")\vote!
        true

      assert PollVotes\find {
        poll_choice_id: choice.id,
        user_id: current_user.id
      }

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
