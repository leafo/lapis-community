describe "community.helpers", ->

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
    describe "page_number", ->
      local page_number

      before_each ->
        import page_number from require "community.helpers.shapes"

      it "passes valid value", ->
        assert.same 1, page_number\transform "1"
        assert.same 200, page_number\transform "200"
        assert.same 5, page_number\transform " 5 "

        assert.same 1, page_number\transform 1
        assert.same 50, page_number\transform 50
        assert.same 1, page_number\transform -20
        assert.same 3, page_number\transform 3.5

        assert.same 1, page_number\transform nil
        assert.same 1, page_number\transform ""

      it "fails invalid string", ->
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "hello"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "nil"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform " 5 f"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "-5"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "5.3"}

    describe "valid_text", ->
      local valid_text

      before_each ->
        import valid_text from require "community.helpers.shapes"

      it "passes valid string", ->
        assert.same "Hello world", valid_text\transform "Hello world"
        assert.same " Hello world ", valid_text\transform " Hello world "

      it "strips invalid chars", ->
        assert.same "ummandf", valid_text\transform "\008\000umm\127and\200f"

    describe "trimmed_text", ->
      local trimmed_text

      before_each ->
        import trimmed_text from require "community.helpers.shapes"

      it "trims text", ->
        assert.same "Hello world", trimmed_text\transform "Hello world"
        assert.same "Hello world", trimmed_text\transform " Hello world "

    describe "limited_text", ->
      local limited_text

      before_each ->
        import limited_text from require "community.helpers.shapes"

      it "passes valid text", ->
        assert.same "hello", limited_text(10)\transform "hello"
        assert.same "hello", limited_text(10)\transform "   hello           "
        assert.same "hello", limited_text(10)\transform " \200  hello   \000\008        "

      it "fails with text outside range", ->
        assert.same {nil, "expected text between 1 and 10 characters"}, { limited_text(10)\transform "helloworldthisfails" }
        assert.same {nil, "expected text between 1 and 10 characters"}, { limited_text(10)\transform "" }

    describe "db_id", ->
      local db_id

      before_each ->
        import db_id from require "community.helpers.shapes"

      it "transforms valid db id", ->
        assert.same 100, db_id\transform "100"
        assert.same 238023, db_id\transform 238023

      it "fails with invalid id", ->
        assert.same {nil, "expected database id"}, { db_id\transform -2 }
        assert.same {nil, "expected integer"}, { db_id\transform "-2" }
        assert.same {nil, "expected database id"}, { db_id\transform "293823802308283203920838902392" }
        assert.same {nil, "expected integer"}, { db_id\transform "43iwhoa" }

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

      it "fails with custom label", ->
        assert.same {
          nil, {
            [[Hello: expected "blue"]]
          }
        }, {
          test_valid {
            color: 200
          }, {
            {"color", label: "Hello", types.literal "blue" }
          }
        }

      it "fails with custom error", ->
        assert.same {
          nil, {
            [[You gave wrong color]]
          }
        }, {
          test_valid {
            color: 200
          }, {
            {"color", error: "You gave wrong color", types.literal "blue" }
          }
        }


