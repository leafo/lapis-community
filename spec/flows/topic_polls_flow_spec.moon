import in_request from require "spec.flow_helpers"

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
      @current_user = current_user
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
      @current_user = current_user
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
