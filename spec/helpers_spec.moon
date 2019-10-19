import use_test_env from require "lapis.spec"

describe "community.helpers", ->
  use_test_env!

  describe "models", ->
    import memoize1 from require "community.helpers.models"

    it "memoizes method", ->
      class M
        calls: 0

        new: (@initial) =>

        value: memoize1 (t) =>
          @calls += 1
          @initial + t.amount

      a = M 2
      b = M 3

      i1 = amount: 2
      i2 = amount: 3

      assert.same 4, a\value i1
      assert.same 5, a\value i2
      assert.same 4, a\value i1

      assert.same 2, a.calls

      assert.same 5, b\value i1
      assert.same 6, b\value i2
      assert.same 5, b\value i1

      assert.same 2, b.calls


  describe "shapes", ->
    describe "test_valid", ->
      local test_valid, types

      before_each ->
        import test_valid from require "community.helpers.shapes"
        import types from require "tableshape"

      it "fails when receiving non-object", ->
        assert.same {
          nil, {[[expected type "table", got "string"]]}
        }, {
          test_valid "hello", {
            {"color", types.literal "blue" }
          }
        }

      it "tests passing object", ->
        assert.same {
          { color: "blue" }
        }, {
          test_valid {
            color: "blue"
            something: "else"
          }, {
            {"color", types.literal "blue" }
          }
        }

      it "tests passing object with transform", ->
        obj = {
          color: "blue"
          something: "else"
        }

        assert.same {
          { color: true }
        }, {
          test_valid obj, {
            {"color", types.literal("blue") / true }
          }
        }

        -- obj is unchanged
        assert.same {
          color: "blue"
          something: "else"
        }, obj

      it "fails with single error", ->
        assert.same {
          nil, {
            [[color: expected "blue"]]
          }
        }, {
          test_valid {
            height: "green"
          }, {
            {"color", types.literal "blue" }
          }
        }

        assert.same {
          nil, {
            [[color: expected "blue"]]
          }
        }, {
          test_valid { }, {
            {"color", types.literal "blue" }
          }
        }

        assert.same {
          nil, {
            [[color: expected "blue"]]
          }
        }, {
          test_valid {
            color: {}
          }, {
            {"color", types.literal "blue" }
          }
        }


      it "fails with multiple errors", ->
        assert.same {
          nil, {
            [[color: expected "blue"]]
            [[height: expected type "number", got "nil"]]
          }
        }, {
          test_valid {
            color: 200
            age: 4
          }, {
            {"color", types.literal "blue" }
            {"height", types.number }
            {"age", types.number }
          }
        }


